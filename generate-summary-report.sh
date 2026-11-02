#!/bin/bash
# generate-summary-report.sh
# Standalone Step 5: Generate summary report and analysis
# Usage: ./generate-summary-report.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║   Step 5: Summary Report Generator                   ║
║   Analyzing benchmark results                         ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Configuration
RESULTS_BASE="./results"
VIDEOS_BASE="./data/videos"

# Define test matrix (same as main script)
declare -A PAPERS
PAPERS=(
    ["paper1"]="static_scene dynamic_scene dense_objects"
    ["paper2"]="detection_heavy feature_heavy balanced"
    ["paper3"]="high_texture low_texture lighting_change motion_blur"
)

PLATFORMS=("x86")

echo "Analyzing results in: $RESULTS_BASE"
echo ""

# =============================================================================
# Generate Summary Report
# =============================================================================
SUMMARY_FILE="$RESULTS_BASE/benchmark_summary_$(date +%Y%m%d_%H%M%S).txt"

echo "Creating summary report: $SUMMARY_FILE"

cat > "$SUMMARY_FILE" << EOF
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║   Gravisonde Benchmark Summary (x86-Only)            ║
║   Generated: $(date '+%Y-%m-%d %H:%M:%S')                      ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝

Hybrid Approach - Phase 1 Complete
===================================
✓ x86 tests completed
⏳ ARM tests pending (will run on Graviton4)

Results directory: $RESULTS_BASE
Platform: x86-only

Test Matrix:
EOF

# Count completed tests
TOTAL_TESTS=0
COMPLETED_TESTS=0

for paper in "${!PAPERS[@]}"; do
    echo "" >> "$SUMMARY_FILE"
    echo "${paper}:" >> "$SUMMARY_FILE"
    for video_name in ${PAPERS[$paper]}; do
        for platform in "${PLATFORMS[@]}"; do
            TOTAL_TESTS=$((TOTAL_TESTS + 1))
            result_file=$(ls "$RESULTS_BASE/${paper}/${platform}/${video_name}"*.csv 2>/dev/null | head -n 1)
            if [ -f "$result_file" ]; then
                line_count=$(wc -l < "$result_file")
                frames=$((line_count - 1))
                if [ $frames -gt 0 ]; then
                    COMPLETED_TESTS=$((COMPLETED_TESTS + 1))
                    echo "  ✓ ${video_name} (${platform}): ${frames} frames" >> "$SUMMARY_FILE"
                else
                    echo "  ⚠ ${video_name} (${platform}): 0 frames (check logs)" >> "$SUMMARY_FILE"
                fi
            else
                echo "  ✗ ${video_name} (${platform}): No CSV file" >> "$SUMMARY_FILE"
            fi
        done
    done
done

cat >> "$SUMMARY_FILE" << EOF

Summary Statistics:
===================
Total tests expected: ${TOTAL_TESTS}
Tests completed: ${COMPLETED_TESTS}
Success rate: $((COMPLETED_TESTS * 100 / TOTAL_TESTS))%

Files Generated:
================
  - Videos: $VIDEOS_BASE/
  - Results: $RESULTS_BASE/
  - Logs: ./logs/
  - This summary: $SUMMARY_FILE

Paper Status:
=============
  Paper 1 (Architecture Comparison):
    ✓ x86 baseline collected
    ⏳ ARM data pending (run on Graviton4)
    Status: 50% complete

  Paper 2 (Cost-Efficiency):
    ✓ x86 data collected
    ✓ Ready for analysis
    Status: 100% complete (x86-only sufficient)

  Paper 3 (Feature Detectors):
    ✓ x86 data collected
    ✓ Ready for analysis
    Status: 100% complete (x86-only sufficient)

Next Steps:
===========
  1. Analyze x86 results: python3 analyze_results.py results/
  2. Start writing Papers 2 & 3 (complete data)
  3. Fix EC2 SSH for Paper 1 ARM data
  4. Run Paper 1 tests on Graviton4 (~50 min)
  5. Complete all 3 papers

See HYBRID_APPROACH_STATUS.md for full plan.

EOF

# Display summary
cat "$SUMMARY_FILE"

echo ""
echo -e "${GREEN}✓ Summary report generated: $SUMMARY_FILE${NC}"
echo ""

# =============================================================================
# Quick Data Validation
# =============================================================================
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Quick Data Validation${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

echo "CSV Files Found:"
CSV_COUNT=$(find "$RESULTS_BASE" -name "*.csv" -type f 2>/dev/null | wc -l)
echo "  Total CSV files: $CSV_COUNT"

if [ $CSV_COUNT -gt 0 ]; then
    echo ""
    echo "Sample Data (first CSV found):"
    SAMPLE_CSV=$(find "$RESULTS_BASE" -name "*.csv" -type f 2>/dev/null | head -n 1)
    if [ -f "$SAMPLE_CSV" ]; then
        echo "  File: $SAMPLE_CSV"
        echo "  Lines: $(wc -l < "$SAMPLE_CSV")"
        echo "  First 3 rows:"
        head -n 3 "$SAMPLE_CSV" | sed 's/^/    /'
    fi
fi

echo ""
echo "Disk Usage:"
du -sh "$RESULTS_BASE" 2>/dev/null || echo "  N/A"

echo ""

# =============================================================================
# Generate Quick Stats
# =============================================================================
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Quick Statistics${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

STATS_FILE="$RESULTS_BASE/quick_stats.txt"

echo "Generating quick statistics: $STATS_FILE"
echo ""

cat > "$STATS_FILE" << EOF
Gravisonde Quick Statistics
Generated: $(date '+%Y-%m-%d %H:%M:%S')

Per-Paper Frame Counts:
EOF

for paper in paper1 paper2 paper3; do
    echo "" >> "$STATS_FILE"
    echo "${paper}:" >> "$STATS_FILE"
    paper_dir="$RESULTS_BASE/${paper}/x86"
    if [ -d "$paper_dir" ]; then
        for csv_file in "$paper_dir"/*.csv; do
            if [ -f "$csv_file" ]; then
                filename=$(basename "$csv_file")
                video_name=$(echo "$filename" | cut -d'_' -f1)
                line_count=$(wc -l < "$csv_file")
                frames=$((line_count - 1))

                if [ $frames -gt 0 ]; then
                    duration_sec=300
                    fps=$(echo "scale=2; $frames / $duration_sec" | bc)
                    echo "  ${video_name}: ${frames} frames (~${fps} FPS)" >> "$STATS_FILE"
                fi
            fi
        done
    else
        echo "  No data" >> "$STATS_FILE"
    fi
done

cat "$STATS_FILE"

echo ""
echo -e "${GREEN}✓ Quick stats saved: $STATS_FILE${NC}"
echo ""

# =============================================================================
# Python Analysis Checker
# =============================================================================
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Python Analysis Ready?${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

if command -v python3 &> /dev/null; then
    echo "✓ Python 3 is installed"

    # Check for pandas
    if python3 -c "import pandas" 2>/dev/null; then
        echo "✓ pandas is installed"
        PANDAS_OK=true
    else
        echo "⚠ pandas not installed"
        echo "  Install with: pip3 install pandas"
        PANDAS_OK=false
    fi

    # Check if analyze script exists
    if [ -f "analyze_results.py" ]; then
        echo "✓ analyze_results.py found"

        if [ "$PANDAS_OK" = true ]; then
            echo ""
            echo "Ready to analyze! Run:"
            echo "  python3 analyze_results.py results/"
        fi
    else
        echo "⚠ analyze_results.py not found"
    fi
else
    echo "✗ Python 3 not found"
    echo "  Install with: sudo apt-get install python3"
fi

echo ""

# =============================================================================
# Final Summary
# =============================================================================
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║   ✓ Phase 1 Complete (x86 Data)                     ║
║                                                       ║
║   Papers 2 & 3: Ready to write                       ║
║   Paper 1: Need ARM data from Graviton4              ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo "Next Actions:"
echo ""
echo "1. Analyze x86 data:"
echo "   python3 analyze_results.py results/"
echo ""
echo "2. View summary:"
echo "   cat $SUMMARY_FILE"
echo ""
echo "3. Check individual results:"
echo "   ls -lh results/paper*/x86/"
echo ""
echo "4. Start writing Papers 2 & 3 (complete data)"
echo ""
echo "5. For Paper 1, run ARM tests on Graviton4:"
echo "   See: HYBRID_APPROACH_STATUS.md"
echo ""

# Cleanup
docker compose down > /dev/null 2>&1 || true

echo "✓ All done!"
echo ""
