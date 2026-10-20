#!/usr/bin/env python3
"""Gravisonde — Benchmark runner.

Runs the pipeline for a fixed duration and outputs a CSV of frame metrics.
Usage:
    python -m bench.runner --duration 300 --pipeline cool --output /tmp/bench.csv
"""

import argparse
import time
import sys
import os
import csv

# Ensure src is on path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from main import run_pipeline, init_collector


class CSVCollector:
    """Collector that writes frame metrics to a CSV file instead of CloudWatch."""

    def __init__(self, output_path: str):
        self.output_path = output_path
        self.file = None
        self.writer = None

    def start(self):
        self.file = open(self.output_path, "w", newline="")
        self.writer = csv.writer(self.file)
        self.writer.writerow([
            "frame_id", "ts", "latency_ms", "inference_ms",
            "detections", "instance_id", "opencv_version",
            "cool_version", "arch", "pipeline"
        ])
        self.file.flush()

    def record(self, metric):
        self.writer.writerow([
            metric.frame_id, metric.ts, metric.latency_ms,
            metric.inference_ms, metric.detections,
            metric.instance_id, metric.opencv_version,
            metric.cool_version or "", metric.arch, metric.pipeline
        ])
        self.file.flush()

    def finish(self):
        if self.file:
            self.file.close()


def main():
    parser = argparse.ArgumentParser(description="Run Gravisonde benchmark")
    parser.add_argument("--duration", type=int, default=60, help="Duration in seconds")
    parser.add_argument("--pipeline", choices=["cool", "stock"], default="cool", help="Pipeline mode")
    parser.add_argument("--output", default="/tmp/bench.csv", help="Output CSV path")
    parser.add_argument("--source", default="/data/sample.mp4", help="Video source")
    parser.add_argument("--instance-id", default="gravisonde-bench", help="Instance identifier")
    parser.add_argument("--opencv-version", default="5.0.0.93", help="OpenCV version")
    parser.add_argument("--cool-version", default=None, help="COOL version")
    parser.add_argument("--arch", choices=["graviton", "x86"], default="graviton", help="Architecture")
    parser.add_argument("--instance-type", default="c8g.xlarge", help="Instance type")
    parser.add_argument("--hourly-cost", type=float, default=0.136, help="Hourly cost USD")
    args = parser.parse_args()

    # Create CSV collector
    csv_collector = CSVCollector(args.output)
    csv_collector.start()

    # Run pipeline with CSV collector
    run_pipeline(
        source=args.source,
        instance_id=args.instance_id,
        opencv_version=args.opencv_version,
        cool_version=args.cool_version,
        arch=args.arch,
        pipeline=args.pipeline,
        instance_type=args.instance_type,
        hourly_cost_usd=args.hourly_cost,
        push_interval_sec=10,
        dashboard_endpoint=None,
        duration_sec=args.duration,
    )

    csv_collector.finish()
    print(f"Benchmark complete. CSV written to {args.output}")


if __name__ == "__main__":
    main()