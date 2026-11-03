#!/usr/bin/env python3
"""
Gravisonde Results Analyzer
Extracts benchmark statistics from pipeline logs and generates comparison tables.
"""

import re
import json
import sys
from pathlib import Path
from typing import List, Dict, Any
from statistics import mean, median, stdev
import argparse


def parse_log_file(log_path: Path) -> Dict[str, Any]:
    """Parse a pipeline log file and extract frame metrics."""

    metrics = {
        'frames': [],
        'latencies': [],
        'inference_times': [],
        'detections': [],
        'fps_samples': [],
    }

    with open(log_path, 'r') as f:
        for line in f:
            # Extract frame processing metrics
            # Example: "Frame 1234: latency=12.3ms, inference=10.5ms, detections=5"
            frame_match = re.search(r'Frame (\d+).*?latency[=:]?\s*([\d.]+)\s*ms.*?inference[=:]?\s*([\d.]+)\s*ms.*?detections[=:]?\s*(\d+)', line, re.IGNORECASE)
            if frame_match:
                frame_id, latency, inference, det_count = frame_match.groups()
                metrics['frames'].append(int(frame_id))
                metrics['latencies'].append(float(latency))
                metrics['inference_times'].append(float(inference))
                metrics['detections'].append(int(det_count))

            # Extract FPS metrics
            # Example: "FPS: 45.2" or "Current FPS: 45.2"
            fps_match = re.search(r'(?:current\s+)?fps[=:]?\s*([\d.]+)', line, re.IGNORECASE)
            if fps_match:
                metrics['fps_samples'].append(float(fps_match.group(1)))

    return metrics


def calculate_statistics(metrics: Dict[str, Any]) -> Dict[str, Any]:
    """Calculate benchmark statistics from parsed metrics."""

    if not metrics['latencies']:
        return {
            'error': 'No metrics found in log file',
            'total_frames': 0,
        }

    latencies_sorted = sorted(metrics['latencies'])

    stats = {
        'total_frames': len(metrics['frames']),
        'avg_latency_ms': mean(metrics['latencies']),
        'median_latency_ms': median(metrics['latencies']),
        'p50_latency_ms': latencies_sorted[len(latencies_sorted) // 2],
        'p95_latency_ms': latencies_sorted[int(len(latencies_sorted) * 0.95)],
        'p99_latency_ms': latencies_sorted[int(len(latencies_sorted) * 0.99)],
        'min_latency_ms': min(metrics['latencies']),
        'max_latency_ms': max(metrics['latencies']),
        'stddev_latency_ms': stdev(metrics['latencies']) if len(metrics['latencies']) > 1 else 0,
        'avg_inference_ms': mean(metrics['inference_times']) if metrics['inference_times'] else 0,
        'avg_detections': mean(metrics['detections']) if metrics['detections'] else 0,
        'total_detections': sum(metrics['detections']),
    }

    # Calculate FPS (frames per second)
    if metrics['fps_samples']:
        stats['avg_fps'] = mean(metrics['fps_samples'])
    elif len(metrics['frames']) >= 2:
        # Estimate from frame count and time
        # Assuming continuous processing
        stats['avg_fps'] = len(metrics['frames']) / 300.0  # 300 sec benchmark
    else:
        stats['avg_fps'] = 0

    return stats


def compare_results(cool_stats: Dict[str, Any], stock_stats: Dict[str, Any]) -> Dict[str, Any]:
    """Generate comparison metrics between COOL and Stock pipelines."""

    comparison = {}

    # FPS comparison
    if cool_stats.get('avg_fps', 0) > 0 and stock_stats.get('avg_fps', 0) > 0:
        comparison['fps_improvement_pct'] = ((cool_stats['avg_fps'] - stock_stats['avg_fps']) / stock_stats['avg_fps']) * 100

    # Latency comparison
    if cool_stats.get('p50_latency_ms', 0) > 0 and stock_stats.get('p50_latency_ms', 0) > 0:
        comparison['p50_latency_improvement_pct'] = ((stock_stats['p50_latency_ms'] - cool_stats['p50_latency_ms']) / stock_stats['p50_latency_ms']) * 100

    if cool_stats.get('p95_latency_ms', 0) > 0 and stock_stats.get('p95_latency_ms', 0) > 0:
        comparison['p95_latency_improvement_pct'] = ((stock_stats['p95_latency_ms'] - cool_stats['p95_latency_ms']) / stock_stats['p95_latency_ms']) * 100

    # Cost efficiency (c8g.xlarge = $0.136/hour)
    hourly_cost = 0.136
    if cool_stats.get('avg_fps', 0) > 0:
        comparison['cool_fps_per_dollar'] = cool_stats['avg_fps'] / hourly_cost
    if stock_stats.get('avg_fps', 0) > 0:
        comparison['stock_fps_per_dollar'] = stock_stats['avg_fps'] / hourly_cost

    if comparison.get('cool_fps_per_dollar', 0) > 0 and comparison.get('stock_fps_per_dollar', 0) > 0:
        comparison['cost_efficiency_improvement_pct'] = ((comparison['cool_fps_per_dollar'] - comparison['stock_fps_per_dollar']) / comparison['stock_fps_per_dollar']) * 100

    return comparison


def print_report(cool_stats: Dict[str, Any], stock_stats: Dict[str, Any], comparison: Dict[str, Any]):
    """Print formatted comparison report."""

    print("\n" + "="*80)
    print("GRAVISONDE BENCHMARK RESULTS - COOL vs Stock OpenCV")
    print("="*80 + "\n")

    print("COOL Pipeline (OpenCV 5 + COOL optimizations)")
    print("-" * 50)
    print(f"  Total Frames:       {cool_stats.get('total_frames', 0):,}")
    print(f"  Average FPS:        {cool_stats.get('avg_fps', 0):.2f}")
    print(f"  P50 Latency:        {cool_stats.get('p50_latency_ms', 0):.2f} ms")
    print(f"  P95 Latency:        {cool_stats.get('p95_latency_ms', 0):.2f} ms")
    print(f"  P99 Latency:        {cool_stats.get('p99_latency_ms', 0):.2f} ms")
    print(f"  Avg Inference:      {cool_stats.get('avg_inference_ms', 0):.2f} ms")
    print(f"  Total Detections:   {cool_stats.get('total_detections', 0):,}")
    print()

    print("Stock Pipeline (Standard OpenCV 5)")
    print("-" * 50)
    print(f"  Total Frames:       {stock_stats.get('total_frames', 0):,}")
    print(f"  Average FPS:        {stock_stats.get('avg_fps', 0):.2f}")
    print(f"  P50 Latency:        {stock_stats.get('p50_latency_ms', 0):.2f} ms")
    print(f"  P95 Latency:        {stock_stats.get('p95_latency_ms', 0):.2f} ms")
    print(f"  P99 Latency:        {stock_stats.get('p99_latency_ms', 0):.2f} ms")
    print(f"  Avg Inference:      {stock_stats.get('avg_inference_ms', 0):.2f} ms")
    print(f"  Total Detections:   {stock_stats.get('total_detections', 0):,}")
    print()

    print("COMPARISON (COOL vs Stock)")
    print("-" * 50)
    if 'fps_improvement_pct' in comparison:
        print(f"  FPS Improvement:    {comparison['fps_improvement_pct']:+.2f}%")
    if 'p50_latency_improvement_pct' in comparison:
        print(f"  P50 Latency Improvement:  {comparison['p50_latency_improvement_pct']:+.2f}%")
    if 'p95_latency_improvement_pct' in comparison:
        print(f"  P95 Latency Improvement:  {comparison['p95_latency_improvement_pct']:+.2f}%")
    if 'cost_efficiency_improvement_pct' in comparison:
        print(f"  Cost Efficiency Improvement: {comparison['cost_efficiency_improvement_pct']:+.2f}%")
    if 'cool_fps_per_dollar' in comparison and 'stock_fps_per_dollar' in comparison:
        print(f"  COOL FPS/$:         {comparison['cool_fps_per_dollar']:.2f}")
        print(f"  Stock FPS/$:        {comparison['stock_fps_per_dollar']:.2f}")
    print()

    print("="*80 + "\n")


def main():
    parser = argparse.ArgumentParser(description='Analyze Gravisonde benchmark results')
    parser.add_argument('--cool-log', required=True, help='Path to COOL pipeline log file')
    parser.add_argument('--stock-log', required=True, help='Path to Stock pipeline log file')
    parser.add_argument('--output', default='benchmark_report.json', help='Output JSON file')
    args = parser.parse_args()

    cool_log = Path(args.cool_log)
    stock_log = Path(args.stock_log)

    if not cool_log.exists():
        print(f"Error: COOL log file not found: {cool_log}")
        sys.exit(1)

    if not stock_log.exists():
        print(f"Error: Stock log file not found: {stock_log}")
        sys.exit(1)

    # Parse logs
    print("Parsing COOL pipeline log...")
    cool_metrics = parse_log_file(cool_log)
    cool_stats = calculate_statistics(cool_metrics)

    print("Parsing Stock pipeline log...")
    stock_metrics = parse_log_file(stock_log)
    stock_stats = calculate_statistics(stock_metrics)

    # Compare results
    comparison = compare_results(cool_stats, stock_stats)

    # Print report
    print_report(cool_stats, stock_stats, comparison)

    # Save JSON report
    report = {
        'timestamp': '2026-11-03T10:00:00Z',
        'instance_type': 'c8g.xlarge',
        'architecture': 'graviton (ARM64)',
        'opencv_version': '5.0.0.93',
        'benchmark_duration_sec': 300,
        'cool': cool_stats,
        'stock': stock_stats,
        'comparison': comparison,
    }

    output_path = Path(args.output)
    with open(output_path, 'w') as f:
        json.dump(report, f, indent=2)

    print(f"✅ Full report saved to: {output_path}")


if __name__ == '__main__':
    main()
