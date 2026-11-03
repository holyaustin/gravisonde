#!/usr/bin/env python3
"""
Generate publication-ready charts from benchmark data.
Outputs PNG/SVG charts for inclusion in technical report.
"""

import json
import sys
from pathlib import Path
import argparse

try:
    import matplotlib.pyplot as plt
    import matplotlib
    matplotlib.use('Agg')  # Non-interactive backend
except ImportError:
    print("Error: matplotlib not installed. Install with: pip install matplotlib")
    sys.exit(1)


def load_report(report_path: Path) -> dict:
    """Load benchmark report JSON."""
    with open(report_path) as f:
        return json.load(f)


def plot_fps_comparison(report: dict, output_dir: Path):
    """Bar chart: FPS comparison."""
    cool_fps = report['cool']['avg_fps']
    stock_fps = report['stock']['avg_fps']

    fig, ax = plt.subplots(figsize=(8, 6))
    bars = ax.bar(['COOL\n(OpenCV 5 + COOL)', 'Stock\n(OpenCV 5)'],
                   [cool_fps, stock_fps],
                   color=['#2563eb', '#64748b'])

    ax.set_ylabel('Frames Per Second (FPS)', fontsize=12)
    ax.set_title('Pipeline Throughput: COOL vs Stock OpenCV\non AWS Graviton (c8g.xlarge)',
                 fontsize=14, fontweight='bold')
    ax.set_ylim(0, max(cool_fps, stock_fps) * 1.2)

    # Add value labels on bars
    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.1f}',
                ha='center', va='bottom', fontsize=11, fontweight='bold')

    # Add improvement annotation
    if 'fps_improvement_pct' in report.get('comparison', {}):
        improvement = report['comparison']['fps_improvement_pct']
        ax.text(0.5, 0.95, f'↑ {improvement:.1f}% improvement',
                transform=ax.transAxes, ha='center', va='top',
                bbox=dict(boxstyle='round', facecolor='lightgreen', alpha=0.8),
                fontsize=10, fontweight='bold')

    plt.tight_layout()
    output_path = output_dir / 'fps_comparison.png'
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    plt.savefig(output_dir / 'fps_comparison.svg', bbox_inches='tight')
    print(f"✅ Saved: {output_path}")
    plt.close()


def plot_latency_comparison(report: dict, output_dir: Path):
    """Grouped bar chart: Latency percentiles."""
    percentiles = ['P50', 'P95', 'P99']
    cool_latencies = [
        report['cool']['p50_latency_ms'],
        report['cool']['p95_latency_ms'],
        report['cool']['p99_latency_ms']
    ]
    stock_latencies = [
        report['stock']['p50_latency_ms'],
        report['stock']['p95_latency_ms'],
        report['stock']['p99_latency_ms']
    ]

    x = range(len(percentiles))
    width = 0.35

    fig, ax = plt.subplots(figsize=(10, 6))
    bars1 = ax.bar([i - width/2 for i in x], cool_latencies, width,
                    label='COOL', color='#2563eb')
    bars2 = ax.bar([i + width/2 for i in x], stock_latencies, width,
                    label='Stock', color='#64748b')

    ax.set_ylabel('Latency (ms)', fontsize=12)
    ax.set_xlabel('Percentile', fontsize=12)
    ax.set_title('Frame Processing Latency: COOL vs Stock OpenCV\non AWS Graviton (c8g.xlarge)',
                 fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(percentiles)
    ax.legend(fontsize=11)

    # Add value labels
    for bars in [bars1, bars2]:
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height,
                    f'{height:.1f}',
                    ha='center', va='bottom', fontsize=9)

    plt.tight_layout()
    output_path = output_dir / 'latency_comparison.png'
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    plt.savefig(output_dir / 'latency_comparison.svg', bbox_inches='tight')
    print(f"✅ Saved: {output_path}")
    plt.close()


def plot_cost_efficiency(report: dict, output_dir: Path):
    """Bar chart: FPS per dollar."""
    comparison = report.get('comparison', {})
    cool_fps_dollar = comparison.get('cool_fps_per_dollar', 0)
    stock_fps_dollar = comparison.get('stock_fps_per_dollar', 0)

    fig, ax = plt.subplots(figsize=(8, 6))
    bars = ax.bar(['COOL', 'Stock'], [cool_fps_dollar, stock_fps_dollar],
                   color=['#16a34a', '#64748b'])

    ax.set_ylabel('FPS per Dollar ($/hour)', fontsize=12)
    ax.set_title('Cost Efficiency: Throughput per Dollar\non AWS Graviton c8g.xlarge ($0.136/hr)',
                 fontsize=14, fontweight='bold')
    ax.set_ylim(0, max(cool_fps_dollar, stock_fps_dollar) * 1.2)

    # Add value labels
    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2., height,
                f'{height:.1f}',
                ha='center', va='bottom', fontsize=11, fontweight='bold')

    # Add improvement annotation
    if 'cost_efficiency_improvement_pct' in comparison:
        improvement = comparison['cost_efficiency_improvement_pct']
        ax.text(0.5, 0.95, f'↑ {improvement:.1f}% better value',
                transform=ax.transAxes, ha='center', va='top',
                bbox=dict(boxstyle='round', facecolor='lightgreen', alpha=0.8),
                fontsize=10, fontweight='bold')

    plt.tight_layout()
    output_path = output_dir / 'cost_efficiency.png'
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    plt.savefig(output_dir / 'cost_efficiency.svg', bbox_inches='tight')
    print(f"✅ Saved: {output_path}")
    plt.close()


def main():
    parser = argparse.ArgumentParser(description='Generate charts from benchmark report')
    parser.add_argument('--report', required=True, help='Path to benchmark_report.json')
    parser.add_argument('--output-dir', default='results/charts', help='Output directory for charts')
    args = parser.parse_args()

    report_path = Path(args.report)
    if not report_path.exists():
        print(f"Error: Report file not found: {report_path}")
        sys.exit(1)

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Loading report from: {report_path}")
    report = load_report(report_path)

    print("\nGenerating charts...")
    plot_fps_comparison(report, output_dir)
    plot_latency_comparison(report, output_dir)
    plot_cost_efficiency(report, output_dir)

    print(f"\n✅ All charts saved to: {output_dir}")
    print(f"   - fps_comparison.png / .svg")
    print(f"   - latency_comparison.png / .svg")
    print(f"   - cost_efficiency.png / .svg")


if __name__ == '__main__':
    main()
