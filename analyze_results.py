#!/usr/bin/env python3
"""
analyze_results.py
Analyze benchmark results and generate statistics for academic papers

Usage: python3 analyze_results.py results/
"""

import os
import sys
import pandas as pd
import json
from pathlib import Path
from datetime import datetime


def load_all_csvs(results_dir):
    """Load all CSV files from results directory"""
    data = {}

    for paper in ['paper1', 'paper2', 'paper3']:
        data[paper] = {'x86': {}, 'arm': {}}

        for platform in ['x86', 'arm']:
            platform_dir = Path(results_dir) / paper / platform
            if not platform_dir.exists():
                continue

            for csv_file in platform_dir.glob('*.csv'):
                try:
                    df = pd.read_csv(csv_file)
                    if len(df) > 0:
                        video_name = csv_file.stem.split('_')[0]  # Extract video name
                        data[paper][platform][video_name] = df
                        print(f"✓ Loaded: {paper}/{platform}/{video_name} ({len(df)} frames)")
                except Exception as e:
                    print(f"✗ Error loading {csv_file}: {e}")

    return data


def calculate_stats(df):
    """Calculate benchmark statistics from DataFrame"""
    if df is None or len(df) == 0:
        return None

    duration_sec = (df['timestamp'].max() - df['timestamp'].min()) / 1000.0

    stats = {
        'total_frames': len(df),
        'duration_sec': round(duration_sec, 2),
        'avg_fps': round(len(df) / duration_sec, 2) if duration_sec > 0 else 0,
        'latency_p50': round(df['latencyMs'].quantile(0.50), 2),
        'latency_p95': round(df['latencyMs'].quantile(0.95), 2),
        'latency_p99': round(df['latencyMs'].quantile(0.99), 2),
        'latency_mean': round(df['latencyMs'].mean(), 2),
        'latency_std': round(df['latencyMs'].std(), 2),
        'inference_mean': round(df['inferenceMs'].mean(), 2),
        'detections_mean': round(df['detections'].mean(), 2),
        'detections_total': int(df['detections'].sum()),
    }

    return stats


def paper1_analysis(data):
    """Paper 1: Architecture Comparison (ARM vs x86)"""
    print("\n" + "="*70)
    print("Paper 1: Architecture-Aware Computer Vision")
    print("ARM Graviton vs x86 Comparison")
    print("="*70 + "\n")

    results = []

    for video in ['static_scene', 'dynamic_scene', 'dense_objects']:
        print(f"\n{video.upper()}:")
        print("-" * 50)

        x86_df = data['paper1']['x86'].get(video)
        arm_df = data['paper1']['arm'].get(video)

        x86_stats = calculate_stats(x86_df)
        arm_stats = calculate_stats(arm_df)

        if x86_stats and arm_stats:
            speedup = arm_stats['avg_fps'] / x86_stats['avg_fps'] if x86_stats['avg_fps'] > 0 else 0
            latency_improvement = ((x86_stats['latency_p99'] - arm_stats['latency_p99']) /
                                  x86_stats['latency_p99'] * 100) if x86_stats['latency_p99'] > 0 else 0

            print(f"  x86  - FPS: {x86_stats['avg_fps']:6.2f} | P99: {x86_stats['latency_p99']:6.2f}ms | Frames: {x86_stats['total_frames']}")
            print(f"  ARM  - FPS: {arm_stats['avg_fps']:6.2f} | P99: {arm_stats['latency_p99']:6.2f}ms | Frames: {arm_stats['total_frames']}")
            print(f"  Speedup: {speedup:.2f}x | P99 Latency Improvement: {latency_improvement:+.1f}%")

            results.append({
                'video': video,
                'x86_fps': x86_stats['avg_fps'],
                'arm_fps': arm_stats['avg_fps'],
                'speedup': speedup,
                'x86_p99': x86_stats['latency_p99'],
                'arm_p99': arm_stats['latency_p99'],
                'latency_improvement_pct': latency_improvement
            })
        elif x86_stats:
            print(f"  x86  - FPS: {x86_stats['avg_fps']:6.2f} | P99: {x86_stats['latency_p99']:6.2f}ms")
            print(f"  ARM  - No data")
        elif arm_stats:
            print(f"  x86  - No data")
            print(f"  ARM  - FPS: {arm_stats['avg_fps']:6.2f} | P99: {arm_stats['latency_p99']:6.2f}ms")

    if results:
        avg_speedup = sum(r['speedup'] for r in results) / len(results)
        avg_latency_imp = sum(r['latency_improvement_pct'] for r in results) / len(results)
        print(f"\n{'OVERALL SUMMARY':^50}")
        print(f"Average ARM Speedup: {avg_speedup:.2f}x")
        print(f"Average P99 Latency Improvement: {avg_latency_imp:+.1f}%")

    return results


def paper2_analysis(data):
    """Paper 2: Cost-Aware Edge Inference"""
    print("\n" + "="*70)
    print("Paper 2: Cost-Aware Edge Inference")
    print("FPS-per-Dollar Analysis")
    print("="*70 + "\n")

    # Cost per hour (example values)
    costs = {
        'x86': 0.170,   # c7i.xlarge equivalent
        'arm': 0.136,   # c8g.xlarge
    }

    results = []

    for video in ['detection_heavy', 'feature_heavy', 'balanced']:
        print(f"\n{video.upper()}:")
        print("-" * 50)

        for platform in ['x86', 'arm']:
            df = data['paper2'][platform].get(video)
            stats = calculate_stats(df)

            if stats:
                fps_per_dollar = stats['avg_fps'] / costs[platform]
                cost_per_1000_frames = (1000.0 / stats['avg_fps'] / 3600.0 * costs[platform]) if stats['avg_fps'] > 0 else 0

                print(f"  {platform.upper():4s} - FPS: {stats['avg_fps']:6.2f} | "
                      f"FPS/$: {fps_per_dollar:7.2f} | Cost/1k frames: ${cost_per_1000_frames:.4f}")

                results.append({
                    'video': video,
                    'platform': platform,
                    'fps': stats['avg_fps'],
                    'fps_per_dollar': fps_per_dollar,
                    'cost_per_1000_frames': cost_per_1000_frames,
                    'hourly_cost': costs[platform]
                })

    if results:
        print(f"\n{'COST EFFICIENCY RANKING':^50}")
        sorted_results = sorted(results, key=lambda x: x['fps_per_dollar'], reverse=True)
        for i, r in enumerate(sorted_results[:5], 1):
            print(f"  {i}. {r['platform'].upper()} - {r['video']}: {r['fps_per_dollar']:.2f} FPS/$")

    return results


def paper3_analysis(data):
    """Paper 3: ALIKED vs ORB Feature Detectors"""
    print("\n" + "="*70)
    print("Paper 3: Learned vs Classical Feature Detectors")
    print("ALIKED+LightGlue vs ORB+BFMatcher")
    print("="*70 + "\n")

    results = []

    for video in ['high_texture', 'low_texture', 'lighting_change', 'motion_blur']:
        print(f"\n{video.upper()}:")
        print("-" * 50)

        # For this analysis, we assume x86=ORB, arm=ALIKED (or vice versa based on config)
        # In reality, you'd run both feature detectors on same platform

        for platform in ['x86', 'arm']:
            df = data['paper3'][platform].get(video)
            stats = calculate_stats(df)

            if stats:
                print(f"  {platform.upper():4s} - FPS: {stats['avg_fps']:6.2f} | "
                      f"Inference: {stats['inference_mean']:5.2f}ms | "
                      f"Detections: {stats['detections_mean']:.1f}/frame")

                results.append({
                    'video': video,
                    'platform': platform,
                    'fps': stats['avg_fps'],
                    'inference_ms': stats['inference_mean'],
                    'detections_per_frame': stats['detections_mean']
                })

    return results


def generate_latex_table(paper_results, paper_name):
    """Generate LaTeX table for paper"""
    print(f"\n{'LaTeX Table for ' + paper_name:^70}")
    print("="*70)

    if paper_name == "Paper 1":
        print("\\begin{table}[h]")
        print("\\centering")
        print("\\begin{tabular}{lrrrr}")
        print("\\hline")
        print("Video & x86 FPS & ARM FPS & Speedup & P99 Improvement \\\\")
        print("\\hline")
        for r in paper_results:
            print(f"{r['video']} & {r['x86_fps']:.2f} & {r['arm_fps']:.2f} & "
                  f"{r['speedup']:.2f}x & {r['latency_improvement_pct']:+.1f}\\% \\\\")
        print("\\hline")
        print("\\end{tabular}")
        print("\\caption{ARM Graviton4 vs x86 Performance Comparison}")
        print("\\end{table}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_results.py <results_directory>")
        sys.exit(1)

    results_dir = sys.argv[1]

    if not os.path.exists(results_dir):
        print(f"Error: Directory {results_dir} does not exist")
        sys.exit(1)

    print("="*70)
    print("Gravisonde Benchmark Analysis")
    print(f"Results directory: {results_dir}")
    print(f"Analysis time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*70)

    # Load all data
    print("\nLoading CSV files...")
    data = load_all_csvs(results_dir)

    # Analyze each paper
    paper1_results = paper1_analysis(data)
    paper2_results = paper2_analysis(data)
    paper3_results = paper3_analysis(data)

    # Generate LaTeX tables
    if paper1_results:
        generate_latex_table(paper1_results, "Paper 1")

    # Save JSON summary
    summary = {
        'analysis_date': datetime.now().isoformat(),
        'paper1': paper1_results,
        'paper2': paper2_results,
        'paper3': paper3_results,
    }

    output_file = os.path.join(results_dir, 'analysis_summary.json')
    with open(output_file, 'w') as f:
        json.dump(summary, f, indent=2)

    print(f"\n{'='*70}")
    print(f"✓ Analysis complete!")
    print(f"✓ Summary saved to: {output_file}")
    print(f"{'='*70}\n")


if __name__ == '__main__':
    main()
