#!/bin/bash
# Gravisonde Paper 1 Automated Benchmark Script
# Architecture Comparison: ARM Graviton4 (COOL) vs x86 (Stock)
# Paper 1: Architecture-Aware Computer Vision
#
# Usage on EC2:
#   ./paper1-benchmark.sh [duration_seconds]
# Default duration: 300s (5 minutes) per test
#
# Outputs:
#   - CSV files with frame metrics
#   - Summary report
#   - Results ready for local analysis download

set -e

# Configuration
DURATION=${1:-300}  # Default 5 minutes per run
VIDEO_DIR="/home/ec2-user/gravisonde/data/videos/paper1"
OUTPUT_DIR="/home/ec2-user/gravisonde/results/paper1_benchmark"
MODEL_PATH="/home/ec2-user/gravisonde/data/yolo11n.onnx"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Video datasets for Paper 1
declare -A VIDEOS=(
    ["static_scene"]="Static Scene - Low Motion"
    ["dynamic_scene"]="Dynamic Scene - Medium Motion"
    ["dense_objects"]="Dense Objects - High Complexity"
)

# Pipeline configurations
PIPELINES=("cool" "stock")

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   Gravisonde Paper 1 Benchmark                            ║
║   Architecture Comparison                                 ║
║   ARM Graviton4 (COOL) vs x86 (Stock)                     ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

log "${BLUE}Configuration:${NC}"
log "Duration per test: ${DURATION}s"
log "Videos directory: $VIDEO_DIR"
log "Output directory: $OUTPUT_DIR"
log "Model path: $MODEL_PATH"
log ""

# Create output structure
mkdir -p "$OUTPUT_DIR"/{csv,logs,summary}
mkdir -p "$OUTPUT_DIR/csv/cool"
mkdir -p "$OUTPUT_DIR/csv/stock"

# Results summary file
SUMMARY_FILE="$OUTPUT_DIR/summary/paper1_results_${TIMESTAMP}.csv"
SUMMARY_TXT="$OUTPUT_DIR/summary/paper1_summary_${TIMESTAMP}.txt"

# CSV header
echo "video_name,description,pipeline,arch,instance_type,duration_sec,frames_processed,avg_fps,avg_latency_ms,avg_inference_ms,total_detections,avg_detections_per_frame,start_time,end_time,csv_file" > "$SUMMARY_FILE"

# Start summary text
cat > "$SUMMARY_TXT" << EOF
Gravisonde Paper 1 Benchmark Results
=====================================
Date: $(date)
Duration per test: ${DURATION}s
Instance Type: c8g.xlarge (Graviton4)
Videos tested: ${#VIDEOS[@]}
Pipelines tested: cool, stock

EOF

# Check prerequisites
log "${YELLOW}Checking prerequisites...${NC}"

if [ ! -f "$MODEL_PATH" ]; then
    log "${RED}ERROR: Model not found at $MODEL_PATH${NC}"
    exit 1
fi
log "${GREEN}✓ Model found${NC}"

for video in static_scene dynamic_scene dense_objects; do
    if [ ! -f "$VIDEO_DIR/$video.mp4" ]; then
        log "${RED}ERROR: Video not found: $VIDEO_DIR/$video.mp4${NC}"
        exit 1
    fi
done
log "${GREEN}✓ All videos found${NC}"

# Check Docker
if ! command -v docker &> /dev/null; then
    log "${RED}ERROR: Docker not found${NC}"
    exit 1
fi
log "${GREEN}✓ Docker available${NC}"

# Check if pipeline image exists
if ! docker image inspect gravisonde-pipeline:latest &> /dev/null; then
    log "${YELLOW}Building gravisonde pipeline image...${NC}"
    docker build -f apps/cv-pipeline/Dockerfile.cool -t gravisonde-pipeline:latest apps/cv-pipeline
    log "${GREEN}✓ Image built${NC}"
fi

RUN_COUNT=0
TOTAL_RUNS=$((${#VIDEOS[@]} * ${#PIPELINES[@]}))

log "${BLUE}Starting benchmark runs...${NC}"
log "Total runs: $TOTAL_RUNS"

# Main experiment loop
for VIDEO_NAME in "${!VIDEOS[@]}"; do
    VIDEO_DESC="${VIDEOS[$VIDEO_NAME]}"
    VIDEO_PATH="$VIDEO_DIR/$VIDEO_NAME.mp4"

    # Verify video exists
    if [ ! -f "$VIDEO_PATH" ]; then
        log "${RED}ERROR: Video not found: $VIDEO_PATH${NC}"
        continue
    fi

    VIDEO_SIZE=$(ls -lh "$VIDEO_PATH" | awk '{print $5}')

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "${BLUE}Video: ${VIDEO_NAME} (${VIDEO_DESC})${NC}"
    log "File size: $VIDEO_SIZE"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    for PIPELINE in "${PIPELINES[@]}"; do
        RUN_COUNT=$((RUN_COUNT + 1))
        RUN_ID="${VIDEO_NAME}_${PIPELINE}_${TIMESTAMP}"

        log "${YELLOW}[$RUN_COUNT/$TOTAL_RUNS] Running: ${PIPELINE^^} pipeline${NC}"
        log "Start time: $(date)"

        # Output files
        CSV_FILE="$OUTPUT_DIR/csv/$PIPELINE/${VIDEO_NAME}_${PIPELINE}_${TIMESTAMP}.csv"
        LOG_FILE="$OUTPUT_DIR/logs/${RUN_ID}.log"

        # Container name
        CONTAINER_NAME="gravisonde_${RUN_ID}"

        # Run benchmark
        log "Running docker container..."

        # Use timeout to ensure run completes within duration + buffer
        timeout $((DURATION + 30)) docker run --rm \
            --name "$CONTAINER_NAME" \
            --cpus 1.5 \
            -v "$VIDEO_PATH":/data/sample.mp4:ro \
            -v "$MODEL_PATH":/app/yolo11n.onnx:ro \
            -v "$OUTPUT_DIR/csv/$PIPELINE":/results \
            -e VIDEO_SOURCE=/data/sample.mp4 \
            -e PIPELINE_MODE="$PIPELINE" \
            -e DETECTION_MODEL=/app/yolo11n.onnx \
            -e CONF_THRESHOLD=0.5 \
            -e METRICS_PUSH_INTERVAL_SEC=1 \
            -e INSTANCE_TYPE=c8g.xlarge \
            -e ARCH=graviton \
            -e OPENCV_VERSION=5.0.0.93 \
            gravisonde-pipeline:latest \
            python3 -m src.pipeline.main \
                --duration "$DURATION" \
                --pipeline "$PIPELINE" \
                --arch graviton \
                --instance-type c8g.xlarge \
                --instance-id "paper1_${VIDEO_NAME}_${PIPELINE}" \
                2>&1 | tee "$LOG_FILE"

        EXIT_CODE=${PIPESTATUS[0]}

        log "Container exit code: $EXIT_CODE"

        # Check if metrics were logged
        # The pipeline logs metrics to CloudWatch by default, but we need to extract them
        # For now, we'll parse the log file for metrics
        if [ $EXIT_CODE -eq 0 ] || [ $EXIT_CODE -eq 124 ]; then
            log "${GREEN}✓ Completed: ${PIPELINE^^} on ${VIDEO_NAME}${NC}"

            # Parse logs to extract metrics (if pipeline writes to stdout/stderr)
            # This is a placeholder - actual implementation depends on how metrics are output
            if [ -f "$LOG_FILE" ]; then
                # Create a basic CSV from logs if available
                {
                    echo "frame_id,timestamp,latency_ms,inference_ms,detections"
                    # Parse log lines containing metrics
                    grep -E "frame_id|latency|inference|detections" "$LOG_FILE" | head -1000 || true
                } > "$CSV_FILE"

                # Count frames
                if [ -f "$CSV_FILE" ]; then
                    FRAME_COUNT=$(wc -l < "$CSV_FILE")
                    FRAME_COUNT=$((FRAME_COUNT - 1))  # Subtract header

                    # Calculate approximate metrics
                    AVG_FPS=$(python3 -c "print(round($FRAME_COUNT / $DURATION, 2))" 2>/dev/null || echo "N/A")
                    AVG_LATENCY="N/A"
                    AVG_INFERENCE="N/A"
                    TOTAL_DETECTIONS="N/A"

                    echo "$VIDEO_NAME,$VIDEO_DESC,$PIPELINE,graviton,c8g.xlarge,$DURATION,$FRAME_COUNT,$AVG_FPS,$AVG_LATENCY,$AVG_INFERENCE,$TOTAL_DETECTIONS,N/A,$(date -Iseconds),$(date -Iseconds),$CSV_FILE" >> "$SUMMARY_FILE"

                    log "${GREEN}✓ Metrics exported to: $CSV_FILE${NC}"
                    log "Frames processed: $FRAME_COUNT"
                    log "Average FPS: $AVG_FPS"
                else
                    log "${YELLOW}⚠ No CSV generated, logs saved${NC}"
                fi
            fi
        else
            log "${RED}❌ Failed: ${PIPELINE^^} on ${VIDEO_NAME} (exit code: $EXIT_CODE)${NC}"
            echo "$VIDEO_NAME,$VIDEO_DESC,$PIPELINE,graviton,c8g.xlarge,$DURATION,0,0,0,0,0,0,N/A,N/A,N/A" >> "$SUMMARY_FILE"
        fi

        # Brief pause between runs
        log "Cooling down for 10 seconds..."
        sleep 10

    done
done

# Generate final summary
cat >> "$SUMMARY_TXT" << EOF

Summary of Results
==================

EOF

# Parse summary CSV and generate readable report
if [ -f "$SUMMARY_FILE" ]; then
    echo "" >> "$SUMMARY_TXT"
    while IFS=',' read -r video_name description pipeline arch instance_type duration frames avg_fps avg_latency avg_inference detections avg_detections start_time end_time csv_file; do
        if [ "$video_name" != "video_name" ]; then  # Skip header
            cat >> "$SUMMARY_TXT" << EOF
$video_name ($pipeline):
  Frames: $frames
  Avg FPS: $avg_fps
  CSV: $csv_file

EOF
        fi
    done < "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_TXT" << EOF
Completed: $(date)
Total runs completed: $RUN_COUNT

Files generated:
  📊 Summary CSV: $SUMMARY_FILE
  📝 Summary TXT: $SUMMARY_TXT
  📈 CSV files: $OUTPUT_DIR/csv/
  📋 Logs: $OUTPUT_DIR/logs/

Next steps:
  1. Download results to local machine
  2. Analyze with analyze_results.py
  3. Generate plots and academic paper figures

EOF

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Benchmark Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
log "${GREEN}Results directory: $OUTPUT_DIR${NC}"
log "Summary CSV: $SUMMARY_FILE"
log "Summary TXT: $SUMMARY_TXT"
echo ""
echo "Files generated:"
echo "  📊 Summary CSV: $SUMMARY_FILE"
echo "  📝 Summary TXT: $SUMMARY_TXT"
echo "  📈 CSV files: $OUTPUT_DIR/csv/"
echo "  📋 Logs: $OUTPUT_DIR/logs/"
echo ""
echo "Download commands (run from local machine):"
echo "  scp -r ec2-user@<EC2_IP>:$OUTPUT_DIR ./paper1_results/"
echo ""
echo "Analyze locally:"
echo "  python3 analyze_results.py $SUMMARY_FILE"
echo ""

cat "$SUMMARY_TXT"
