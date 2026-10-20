"""Gravisonde — Main pipeline entrypoint.

Runs the OpenCV 5 detector continuously on a video source, collecting
metrics and emitting them to CloudWatch via the MetricsCollector.
Usages:
    python -m gravisonde.pipeline.main     # simple CLI
    # Or via: python -m pipeline.main (run from cv-pipeline/src/)
"""

import argparse
import time
import logging
import sys
import cv2
import numpy as np
from pathlib import Path

from .capture import VideoCapture
from .detection import Detector
from .metrics import init_collector, MetricsCollector, FrameMetric

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger(__name__)


def run_pipeline(
    source: str = "/data/sample.mp4",
    instance_id: str = "gravisonde-demo",
    opencv_version: str = "5.0.0.93",
    cool_version: str | None = None,
    arch: str = "graviton",
    pipeline: str = "cool",
    instance_type: str = "c8g.xlarge",
    hourly_cost_usd: float = 0.136,
    cw_log_group: str = "/aws/gravisonde/pipeline",
    push_interval_sec: int = 10,
    dashboard_endpoint: str | None = None,
    duration_sec: int | None = None,
):
    """Run the full benchmark pipeline.

    - Captures frames from video source
    - Detects objects (YOLO/SSD) + features (ALIKED + LightGlue)
    - Emits FrameMetric to CloudWatch every push_interval_sec
    - If duration_sec is set, auto-starts/stops a benchmark run
    """
    logger.info(f"Starting Gravisonde pipeline: {pipeline} on {arch} ({instance_type})")
    logger.info(f"Video source: {source}")
    logger.info(f"OpenCV {opencv_version}, COOL: {cool_version or 'N/A'}")

    # Initialize the metrics collector
    collector = init_collector(
        instance_id=instance_id,
        opencv_version=opencv_version,
        cool_version=cool_version,
        arch=arch,
        pipeline=pipeline,
        instance_type=instance_type,
        hourly_cost_usd=hourly_cost_usd,
        cw_log_group=cw_log_group,
        push_interval_sec=push_interval_sec,
        dashboard_endpoint=dashboard_endpoint,
    )

    # Start the background emitter (flushes to CloudWatch periodically)
    collector.start_emitter()

    # Open video source
    cap = VideoCapture(source)
    if not cap.isOpened():
        logger.error(f"Cannot open video source: {source}")
        return

    # Initialize the detector
    detector = Detector(conf_threshold=0.5, nms_threshold=0.4, use_lightglue_matcher=True)

    # Start benchmark if duration specified
    run_id = None
    if duration_sec:
        run_id = collector.start_benchmark(duration_sec=duration_sec, video_source=source)

    frame_id = 0
    t0 = time.time()

    try:
        while True:
            success, frame = cap.read()
            if not success or frame is None:
                logger.warning("End of video reached or read failed")
                # Loop the video by recreating the capture
                cap.release()
                cap = VideoCapture(source)
                if not cap.isOpened():
                    logger.error(f"Cannot reopen video source: {source}")
                    break
                continue

            # Measure inference (detection + features) as t1 -> t2
            t1 = time.time()
            detections, features = detector.process_frame(frame)
            t2 = time.time()

            latency_ms = (t2 - t1) * 1000
            inference_ms = (t2 - t1) * 1000  # detection + feature extraction time

            # Record metric
            collector.record_frame(
                frame_id=frame_id,
                latency_ms=latency_ms,
                inference_ms=inference_ms,
                detections=len(detections),
            )

            frame_id += 1

            # Stop benchmark if duration elapsed
            if duration_sec and (time.time() - t0) >= duration_sec:
                logger.info(f"Duration {duration_sec}s elapsed, finishing benchmark")
                run = collector.finish_benchmark(run_id)
                if run:
                    logger.info(f"Benchmark complete: {run.avg_fps:.2f} fps, {run.total_detections} detections")
                break

    except KeyboardInterrupt:
        logger.info("Pipeline interrupted by user")
    finally:
        cap.release()
        collector.stop_emitter()
        logger.info("Pipeline stopped cleanly")


def main():
    parser = argparse.ArgumentParser(description="Gravisonde OpenCV 5 pipeline")
    parser.add_argument("--source", default="/data/sample.mp4", help="Video source path or RTSP URL")
    parser.add_argument("--instance-id", default="gravisonde-demo", help="EC2 instance identifier")
    parser.add_argument("--opencv-version", default="5.0.0.93", help="OpenCV version")
    parser.add_argument("--cool-version", default=None, help="COOL version/commit hash")
    parser.add_argument("--arch", choices=["graviton", "x86"], default="graviton", help="CPU architecture")
    parser.add_argument("--pipeline", choices=["cool", "stock"], default="cool", help="Pipeline mode")
    parser.add_argument("--instance-type", default="c8g.xlarge", help="EC2 instance type")
    parser.add_argument("--hourly-cost", type=float, default=0.136, help="Hourly cost in USD")
    parser.add_argument("--cw-log-group", default="/aws/gravisonde/pipeline", help="CloudWatch log group")
    parser.add_argument("--push-interval", type=int, default=10, help="Metrics emission interval (sec)")
    parser.add_argument("--dashboard-endpoint", default=None, help="HTTP endpoint for live dashboard metrics")
    parser.add_argument("--duration", type=int, default=None, help="Run benchmark for N seconds then exit")
    args = parser.parse_args()

    run_pipeline(
        source=args.source,
        instance_id=args.instance_id,
        opencv_version=args.opencv_version,
        cool_version=args.cool_version,
        arch=args.arch,
        pipeline=args.pipeline,
        instance_type=args.instance_type,
        hourly_cost_usd=args.hourly_cost,
        cw_log_group=args.cw_log_group,
        push_interval_sec=args.push_interval,
        dashboard_endpoint=args.dashboard_endpoint,
        duration_sec=args.duration,
    )


if __name__ == "__main__":
    main()