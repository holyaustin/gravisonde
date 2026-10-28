"""Metrics collection, CloudWatch emission, and benchmark reporting."""

import time
import json
import uuid
import logging
import threading
from datetime import datetime
from dataclasses import dataclass, asdict, field
from typing import List, Optional, Dict, Any
from collections import deque

import boto3
import botocore

logger = logging.getLogger(__name__)

@dataclass
class FrameMetric:
    """Per-frame metric emitted by the pipeline."""
    ts: float                    # time.time()
    frame_id: int
    latency_ms: float            # End-to-end: capture -> detection -> emit
    inference_ms: float          # DNN forward pass only
    detections: int
    instance_id: str
    opencv_version: str
    cool_version: Optional[str]
    arch: str                    # "graviton" | "x86"
    pipeline: str                # "cool" | "stock"

    def to_dict(self) -> Dict[str, Any]:
        return self._to_camel(asdict(self))

    def _to_camel(self, d: Dict[str, Any]) -> Dict[str, Any]:
        """Convert snake_case dataclass fields to camelCase for the dashboard contract."""
        out: Dict[str, Any] = {}
        for key, value in d.items():
            parts = key.split("_")
            camel = parts[0] + "".join(p.capitalize() for p in parts[1:])
            out[camel] = value
        return out

@dataclass
class BenchmarkRun:
    """Summary of a benchmark run."""
    run_id: str
    started_at: str              # ISO 8601
    duration_sec: float
    video_source: str
    frame_count: int
    avg_fps: float
    p50_latency_ms: float
    p95_latency_ms: float
    p99_latency_ms: float
    total_detections: int
    estimated_cost_usd: float
    instance_type: str
    opencv_version: str
    cool_version: Optional[str]
    pipeline: str                # "cool" | "stock"
    notes: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return self._to_camel(asdict(self))

    def _to_camel(self, d: Dict[str, Any]) -> Dict[str, Any]:
        """Convert snake_case dataclass fields to camelCase for the dashboard contract."""
        out: Dict[str, Any] = {}
        for key, value in d.items():
            parts = key.split("_")
            camel = parts[0] + "".join(p.capitalize() for p in parts[1:])
            out[camel] = value
        return out


class MetricsCollector:
    """
    Collects per-frame metrics, emits to CloudWatch, and manages benchmark runs.

    Thread-safe for concurrent frame processing and periodic emission.
    """

    def __init__(
        self,
        instance_id: str,
        opencv_version: str,
        cool_version: Optional[str],
        arch: str,
        pipeline: str,
        instance_type: str = "c8g.xlarge",
        hourly_cost_usd: float = 0.136,
        cw_log_group: str = "/aws/gravisonde/pipeline",
        cw_namespace: str = "Gravisonde/Pipeline",
        s3_bucket: Optional[str] = None,
        aws_region: str = "us-east-1",
        push_interval_sec: int = 10,
        dashboard_endpoint: Optional[str] = None,
        max_buffer_size: int = 10000,
    ):
        self.instance_id = instance_id
        self.opencv_version = opencv_version
        self.cool_version = cool_version
        self.arch = arch
        self.pipeline = pipeline
        self.instance_type = instance_type
        self.hourly_cost_usd = hourly_cost_usd
        self.cw_log_group = cw_log_group
        self.cw_namespace = cw_namespace
        self.s3_bucket = s3_bucket
        self.aws_region = aws_region
        self.push_interval_sec = push_interval_sec
        self.dashboard_endpoint = dashboard_endpoint or None
        self.max_buffer_size = max_buffer_size

        # In-memory ring buffer (last N frames)
        self._buffer: deque = deque(maxlen=max_buffer_size)
        self._lock = threading.RLock()

        # AWS clients (lazy init)
        self._cw_logs = None
        self._cw_metrics = None
        self._s3 = None

        # Benchmark state
        self._benchmark_runs: Dict[str, BenchmarkRun] = {}
        self._current_benchmark: Optional[BenchmarkRun] = None
        self._benchmark_frames: List[FrameMetric] = []

        # Background emitter thread
        self._emitter_thread: Optional[threading.Thread] = None
        self._stop_emitter = threading.Event()

        # HTTP endpoint for pushing to dashboard (optional) – already initialized above

    def _get_clients(self):
        """Lazy initialize AWS clients."""
        if self._cw_logs is None:
            session = boto3.Session(region_name=self.aws_region)
            self._cw_logs = session.client("logs")
            self._cw_metrics = session.client("cloudwatch")
            if self.s3_bucket:
                self._s3 = session.client("s3")

    def start_emitter(self):
        """Start background thread for periodic CloudWatch emission."""
        if self._emitter_thread is not None and self._emitter_thread.is_alive():
            return

        self._stop_emitter.clear()
        self._emitter_thread = threading.Thread(target=self._emitter_loop, daemon=True)
        self._emitter_thread.start()
        logger.info("Metrics emitter started")

    def stop_emitter(self):
        """Stop background emitter thread."""
        self._stop_emitter.set()
        if self._emitter_thread:
            self._emitter_thread.join(timeout=5)
        logger.info("Metrics emitter stopped")

    def _emitter_loop(self):
        """Background loop: flush buffer to CloudWatch periodically."""
        while not self._stop_emitter.is_set():
            time.sleep(self.push_interval_sec)
            if not self._stop_emitter.is_set():
                self.flush()

    def record_frame(
        self,
        frame_id: int,
        latency_ms: float,
        inference_ms: float,
        detections: int,
    ):
        """Record a single frame metric."""
        metric = FrameMetric(
            ts=time.time(),
            frame_id=frame_id,
            latency_ms=latency_ms,
            inference_ms=inference_ms,
            detections=detections,
            instance_id=self.instance_id,
            opencv_version=self.opencv_version,
            cool_version=self.cool_version,
            arch=self.arch,
            pipeline=self.pipeline,
        )

        with self._lock:
            self._buffer.append(metric)

            # If benchmark running, record there too
            if self._current_benchmark:
                self._benchmark_frames.append(metric)

        # Optionally push to dashboard HTTP endpoint
        if self.dashboard_endpoint:
            self._push_to_dashboard(metric)

    def _push_to_dashboard(self, metric: FrameMetric):
        """Push metric to dashboard HTTP endpoint (fire-and-forget)."""
        import threading
        def _post():
            try:
                import requests
                requests.post(
                    self.dashboard_endpoint,
                    json=metric.to_dict(),
                    timeout=1.0
                )
            except Exception:
                pass  # Ignore dashboard push failures

        threading.Thread(target=_post, daemon=True).start()

    def flush(self):
        """Flush buffered metrics to CloudWatch Logs and Metrics."""
        self._get_clients()

        with self._lock:
            if not self._buffer:
                return

            # Batch all buffered metrics
            metrics_batch = list(self._buffer)
            self._buffer.clear()

        # Push to CloudWatch Logs
        self._push_to_cw_logs(metrics_batch)

        # Push aggregated metrics to CloudWatch Metrics
        self._push_to_cw_metrics(metrics_batch)

    def _push_to_cw_logs(self, metrics: List[FrameMetric]):
        """Push metrics as log events to CloudWatch Logs."""
        try:
            # Ensure log group exists
            try:
                self._cw_logs.create_log_group(logGroupName=self.cw_log_group)
            except self._cw_logs.exceptions.ResourceAlreadyExistsException:
                pass

            # Ensure log stream exists
            stream_name = f"{self.instance_id}-{datetime.now().strftime('%Y-%m-%d')}"
            try:
                self._cw_logs.create_log_stream(
                    logGroupName=self.cw_log_group,
                    logStreamName=stream_name
                )
            except self._cw_logs.exceptions.ResourceAlreadyExistsException:
                pass

            # Batch events
            events = []
            for m in metrics:
                events.append({
                    "timestamp": int(m.ts * 1000),
                    "message": json.dumps(m.to_dict())
                })

            # Send in batches of 1000 (CloudWatch limit)
            for i in range(0, len(events), 1000):
                batch = events[i:i+1000]
                self._cw_logs.put_log_events(
                    logGroupName=self.cw_log_group,
                    logStreamName=stream_name,
                    logEvents=batch
                )

            logger.debug(f"Pushed {len(metrics)} metrics to CloudWatch Logs")

        except Exception as e:
            logger.warning(f"Failed to push to CloudWatch Logs: {e}")

    def _push_to_cw_metrics(self, metrics: List[FrameMetric]):
        """Push aggregated metrics to CloudWatch Metrics."""
        if not metrics:
            return

        try:
            # Calculate aggregates
            latencies = [m.latency_ms for m in metrics]
            latencies.sort()
            fps = len(metrics) / (metrics[-1].ts - metrics[0].ts) if len(metrics) > 1 else 0
            avg_detections = sum(m.detections for m in metrics) / len(metrics)

            def percentile(data: List[float], p: float) -> float:
                if not data: return 0
                idx = int(len(data) * p / 100)
                return data[min(idx, len(data) - 1)]

            metric_data = [
                {
                    "MetricName": "FPS",
                    "Value": round(fps, 2),
                    "Unit": "Count/Second",
                    "Dimensions": [
                        {"Name": "InstanceId", "Value": self.instance_id},
                        {"Name": "Pipeline", "Value": self.pipeline},
                    ],
                },
                {
                    "MetricName": "LatencyP50",
                    "Value": round(percentile(latencies, 50), 2),
                    "Unit": "Milliseconds",
                    "Dimensions": [
                        {"Name": "InstanceId", "Value": self.instance_id},
                        {"Name": "Pipeline", "Value": self.pipeline},
                    ],
                },
                {
                    "MetricName": "LatencyP95",
                    "Value": round(percentile(latencies, 95), 2),
                    "Unit": "Milliseconds",
                    "Dimensions": [
                        {"Name": "InstanceId", "Value": self.instance_id},
                        {"Name": "Pipeline", "Value": self.pipeline},
                    ],
                },
                {
                    "MetricName": "LatencyP99",
                    "Value": round(percentile(latencies, 99), 2),
                    "Unit": "Milliseconds",
                    "Dimensions": [
                        {"Name": "InstanceId", "Value": self.instance_id},
                        {"Name": "Pipeline", "Value": self.pipeline},
                    ],
                },
                {
                    "MetricName": "DetectionsPerFrame",
                    "Value": round(avg_detections, 2),
                    "Unit": "Count",
                    "Dimensions": [
                        {"Name": "InstanceId", "Value": self.instance_id},
                        {"Name": "Pipeline", "Value": self.pipeline},
                    ],
                },
                {
                    "MetricName": "FpsPerDollar",
                    "Value": round(fps / self.hourly_cost_usd, 2) if self.hourly_cost_usd > 0 else 0,
                    "Unit": "Count",
                    "Dimensions": [
                        {"Name": "InstanceId", "Value": self.instance_id},
                        {"Name": "Pipeline", "Value": self.pipeline},
                    ],
                },
            ]

            self._cw_metrics.put_metric_data(
                Namespace=self.cw_namespace,
                MetricData=metric_data
            )

            logger.debug(f"Pushed {len(metric_data)} metrics to CloudWatch Metrics")

        except Exception as e:
            logger.warning(f"Failed to push to CloudWatch Metrics: {e}")

    def start_benchmark(
        self,
        duration_sec: int,
        video_source: str,
    ) -> str:
        """Start a new benchmark run."""
        run_id = str(uuid.uuid4())
        started_at = datetime.now().isoformat()

        run = BenchmarkRun(
            run_id=run_id,
            started_at=started_at,
            duration_sec=duration_sec,
            video_source=video_source,
            frame_count=0,
            avg_fps=0,
            p50_latency_ms=0,
            p95_latency_ms=0,
            p99_latency_ms=0,
            total_detections=0,
            estimated_cost_usd=0,
            instance_type=self.instance_type,
            opencv_version=self.opencv_version,
            cool_version=self.cool_version,
            pipeline=self.pipeline,
            notes=f"Benchmark started at {started_at}",
        )

        with self._lock:
            self._benchmark_runs[run_id] = run
            self._current_benchmark = run
            self._benchmark_frames = []

        logger.info(f"Started benchmark {run_id} for {duration_sec}s")
        return run_id

    def finish_benchmark(self, run_id: str) -> Optional[BenchmarkRun]:
        """Finish a benchmark run and compute aggregates."""
        self._get_clients()

        with self._lock:
            run = self._benchmark_runs.get(run_id)
            if not run or not self._benchmark_frames:
                return None

            frames = self._benchmark_frames
            self._current_benchmark = None
            self._benchmark_frames = []

        # Compute aggregates
        latencies = [f.latency_ms for f in frames]
        latencies.sort()
        inferences = [f.inference_ms for f in frames]
        inferences.sort()

        def percentile(data: List[float], p: float) -> float:
            if not data: return 0
            idx = int(len(data) * p / 100)
            return data[min(idx, len(data) - 1)]

        run.frame_count = len(frames)
        run.avg_fps = len(frames) / (frames[-1].ts - frames[0].ts) if len(frames) > 1 else 0
        run.p50_latency_ms = percentile(latencies, 50)
        run.p95_latency_ms = percentile(latencies, 95)
        run.p99_latency_ms = percentile(latencies, 99)
        run.total_detections = sum(f.detections for f in frames)
        run.estimated_cost_usd = (run.duration_sec / 3600) * self.hourly_cost_usd

        # Upload to S3 if configured
        if self.s3_bucket and self._s3:
            self._upload_benchmark(run, frames)

        logger.info(f"Finished benchmark {run_id}: {run.frame_count} frames, {run.avg_fps:.2f} fps")
        return run

    def _upload_benchmark(self, run: BenchmarkRun, frames: List[FrameMetric]):
        """Upload benchmark results to S3 as JSON and CSV."""
        try:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            base_key = f"benchmarks/{run.run_id}_{timestamp}"

            # JSON summary
            json_data = json.dumps(run.to_dict(), indent=2)
            self._s3.put_object(
                Bucket=self.s3_bucket,
                Key=f"{base_key}.json",
                Body=json_data.encode("utf-8"),
                ContentType="application/json"
            )

            # CSV raw frames
            csv_lines = [
                "frame_id,ts,latency_ms,inference_ms,detections,instance_id,opencv_version,cool_version,arch,pipeline"
            ]
            for f in frames:
                csv_lines.append(
                    f"{f.frame_id},{f.ts},{f.latency_ms},{f.inference_ms},{f.detections},"
                    f"{f.instance_id},{f.opencv_version},{f.cool_version or ''},{f.arch},{f.pipeline}"
                )
            csv_data = "\n".join(csv_lines)
            self._s3.put_object(
                Bucket=self.s3_bucket,
                Key=f"{base_key}.csv",
                Body=csv_data.encode("utf-8"),
                ContentType="text/csv"
            )

            logger.info(f"Uploaded benchmark to s3://{self.s3_bucket}/{base_key}.json/.csv")

        except Exception as e:
            logger.warning(f"Failed to upload benchmark to S3: {e}")

    def get_current_stats(self) -> Dict[str, Any]:
        """Get current aggregated stats from buffer (for dashboard)."""
        with self._lock:
            if not self._buffer:
                return {}

            frames = list(self._buffer)
            latencies = [f.latency_ms for f in frames]
            latencies.sort()

            def percentile(data: List[float], p: float) -> float:
                if not data: return 0
                idx = int(len(data) * p / 100)
                return data[min(idx, len(data) - 1)]

            fps = len(frames) / (frames[-1].ts - frames[0].ts) if len(frames) > 1 else 0
            avg_detections = sum(f.detections for f in frames) / len(frames)

            return {
                "fps": round(fps, 2),
                "p50LatencyMs": round(percentile(latencies, 50), 2),
                "p95LatencyMs": round(percentile(latencies, 95), 2),
                "p99LatencyMs": round(percentile(latencies, 99), 2),
                "avgDetections": round(avg_detections, 2),
                "instanceType": self.instance_type,
                "hourlyCostUsd": self.hourly_cost_usd,
                "fpsPerDollar": round(fps / self.hourly_cost_usd, 2) if self.hourly_cost_usd > 0 else 0,
                "arch": self.arch,
                "pipeline": self.pipeline,
                "sampleCount": len(frames),
                "windowStart": int(frames[0].ts * 1000) if frames else 0,
                "windowEnd": int(frames[-1].ts * 1000) if frames else 0,
            }


# Global collector instance (set by main.py)
collector: Optional[MetricsCollector] = None


def get_collector() -> Optional[MetricsCollector]:
    """Get the global metrics collector."""
    return collector


def init_collector(**kwargs) -> MetricsCollector:
    """Initialize the global metrics collector."""
    global collector
    collector = MetricsCollector(**kwargs)
    return collector