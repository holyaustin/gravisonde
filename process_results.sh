#!/bin/bash
# Gravisonde Post-Experiment Data Processing
# Downloads results from EC2, analyzes data, generates charts and report

set -e

EC2_HOST="ec2-user@16.16.75.56"
SSH_KEY="$HOME/.ssh/gravisonde-aws-key1.pem"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="${PROJECT_DIR}/results"

echo "📥 Gravisonde Results Processing Pipeline"
echo "=========================================="
echo ""

# Step 1: Download results from EC2
echo "Step 1: Downloading results from EC2..."
mkdir -p "${RESULTS_DIR}"
scp -i "${SSH_KEY}" -r "${EC2_HOST}:/home/ec2-user/gravisonde/results/*" "${RESULTS_DIR}/" 2>/dev/null || {
    echo "⚠️  Warning: Could not download from EC2. Using local results if available."
}

# Check if log files exist
if [ ! -f "${RESULTS_DIR}/cool_run.log" ] || [ ! -f "${RESULTS_DIR}/stock_run.log" ]; then
    echo "❌ Error: Log files not found in ${RESULTS_DIR}"
    echo "   Expected: cool_run.log and stock_run.log"
    echo ""
    echo "Make sure the benchmark has completed on EC2:"
    echo "  ssh -i ${SSH_KEY} ${EC2_HOST}"
    echo "  cd /home/ec2-user/gravisonde"
    echo "  ./run_benchmark.sh 300"
    exit 1
fi

echo "✅ Results downloaded"
echo ""

# Step 2: Analyze benchmark data
echo "Step 2: Analyzing benchmark data..."
python3 "${PROJECT_DIR}/scripts/analyze_results.py" \
    --cool-log "${RESULTS_DIR}/cool_run.log" \
    --stock-log "${RESULTS_DIR}/stock_run.log" \
    --output "${RESULTS_DIR}/benchmark_report.json"

echo ""

# Step 3: Generate charts
echo "Step 3: Generating publication charts..."
python3 "${PROJECT_DIR}/scripts/generate_charts.py" \
    --report "${RESULTS_DIR}/benchmark_report.json" \
    --output-dir "${RESULTS_DIR}/charts"

echo ""

# Step 4: Display summary
echo "=========================================="
echo "🎉 Processing Complete!"
echo "=========================================="
echo ""
echo "Results location: ${RESULTS_DIR}"
echo ""
echo "Generated files:"
echo "  📊 benchmark_report.json - Full statistical analysis"
echo "  📈 charts/fps_comparison.png - Throughput comparison"
echo "  📈 charts/latency_comparison.png - Latency percentiles"
echo "  📈 charts/cost_efficiency.png - Cost performance"
echo ""
echo "Quick summary:"
python3 -c "
import json
with open('${RESULTS_DIR}/benchmark_report.json') as f:
    r = json.load(f)
    print(f\"  COOL Pipeline:  {r['cool']['avg_fps']:.1f} FPS, P95: {r['cool']['p95_latency_ms']:.1f}ms\")
    print(f\"  Stock Pipeline: {r['stock']['avg_fps']:.1f} FPS, P95: {r['stock']['p95_latency_ms']:.1f}ms\")
    if 'fps_improvement_pct' in r.get('comparison', {}):
        print(f\"  → {r['comparison']['fps_improvement_pct']:+.1f}% FPS improvement\")
    if 'cost_efficiency_improvement_pct' in r.get('comparison', {}):
        print(f\"  → {r['comparison']['cost_efficiency_improvement_pct']:+.1f}% cost efficiency improvement\")
" 2>/dev/null || echo "  (Run 'cat ${RESULTS_DIR}/benchmark_report.json | python3 -m json.tool' for details)"
echo ""
echo "Next steps:"
echo "  1. Review charts in ${RESULTS_DIR}/charts/"
echo "  2. Use data from benchmark_report.json for your paper"
echo "  3. Run: python3 scripts/generate_paper.py (creates technical report)"
echo ""
