#!/bin/bash
# Gravisonde Complete Benchmark Experiment
# Tests COOL vs Stock OpenCV pipelines across 3 video scenarios
# Paper 1: Architecture-Aware Computer Vision (ARM Graviton4)

set -e

DURATION=${1:-300}  # Default 5 minutes per run
DATA_DIR="/home/ec2-user/gravisonde/data"
OUTPUT_DIR="/home/ec2-user/gravisonde/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Video datasets for Paper 1
declare -A VIDEOS
VIDEOS[static]="${DATA_DIR}/videos/paper1/static_scene.mp4"
VIDEOS[dynamic]="${DATA_DIR}/videos/paper1/dynamic_scene.mp4"
VIDEOS[dense]="${DATA_DIR}/videos/paper1/dense_objects.mp4"

# Pipeline configurations
PIPELINES=("cool" "stock")

echo "🚀 Gravisonde Complete Benchmark Experiment"
echo "==========================================="
echo "Date: $(date)"
echo "Duration per run: ${DURATION} seconds"
echo "Total runs: 6 (3 videos × 2 pipelines)"
echo "Estimated total time: ~$((DURATION * 6 / 60)) minutes"
echo ""

# Create results directory structure
mkdir -p "${OUTPUT_DIR}"/{logs,metrics,charts}
mkdir -p "${OUTPUT_DIR}/paper1"

# Stop any running pipeline
echo "Stopping existing pipelines..."
docker-compose -f docker-compose.ec2.yml down 2>/dev/null || true
docker stop $(docker ps -q) 2>/dev/null || true

# Results summary file
SUMMARY_FILE="${OUTPUT_DIR}/paper1/experiment_summary_${TIMESTAMP}.txt"
echo "Gravisonde Benchmark Experiment" > "${SUMMARY_FILE}"
echo "Started: $(date)" >> "${SUMMARY_FILE}"
echo "Duration per run: ${DURATION}s" >> "${SUMMARY_FILE}"
echo "======================================" >> "${SUMMARY_FILE}"
echo "" >> "${SUMMARY_FILE}"

RUN_COUNT=0
TOTAL_RUNS=$((${#VIDEOS[@]} * ${#PIPELINES[@]}))

# Main experiment loop
for VIDEO_NAME in "${!VIDEOS[@]}"; do
  VIDEO_PATH="${VIDEOS[$VIDEO_NAME]}"

  # Verify video exists
  if [ ! -f "$VIDEO_PATH" ]; then
    echo "❌ ERROR: Video not found: $VIDEO_PATH"
    echo "ERROR: Missing video $VIDEO_PATH" >> "${SUMMARY_FILE}"
    continue
  fi

  VIDEO_SIZE=$(ls -lh "$VIDEO_PATH" | awk '{print $5}')
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📹 Video Dataset: ${VIDEO_NAME} (${VIDEO_SIZE})"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  for PIPELINE in "${PIPELINES[@]}"; do
    RUN_COUNT=$((RUN_COUNT + 1))
    RUN_ID="${VIDEO_NAME}_${PIPELINE}"

    echo ""
    echo "[$RUN_COUNT/$TOTAL_RUNS] Running: ${PIPELINE^^} pipeline on ${VIDEO_NAME} scene"
    echo "Started at: $(date)"

    # Output files
    LOG_FILE="${OUTPUT_DIR}/logs/${RUN_ID}_${TIMESTAMP}.log"
    METRICS_FILE="${OUTPUT_DIR}/metrics/${RUN_ID}_${TIMESTAMP}.json"

    # Run benchmark
    docker run --rm \
      --name "gravisonde_${RUN_ID}" \
      --cpus 1.5 \
      -v "$VIDEO_PATH":/data/sample.mp4:ro \
      -v "${DATA_DIR}/yolo11n.onnx":/app/yolo11n.onnx:ro \
      -v "${OUTPUT_DIR}/metrics":/results \
      -e VIDEO_SOURCE=/data/sample.mp4 \
      -e PIPELINE_MODE="${PIPELINE}" \
      -e DETECTION_MODEL=yolo11n.onnx \
      -e CONF_THRESHOLD=0.5 \
      -e METRICS_PUSH_INTERVAL_SEC=1 \
      -e INSTANCE_TYPE=c8g.xlarge \
      -e ARCH=graviton \
      -e OPENCV_VERSION=5.0.0.93 \
      gravisonde-pipeline:latest \
      timeout ${DURATION} python -m src.pipeline.main \
        --duration ${DURATION} \
        --pipeline "${PIPELINE}" \
        --arch graviton \
        --instance-type c8g.xlarge \
        --instance-id "paper1_${VIDEO_NAME}_${PIPELINE}" \
        2>&1 | tee "$LOG_FILE"

    EXIT_CODE=${PIPESTATUS[0]}

    if [ $EXIT_CODE -eq 0 ] || [ $EXIT_CODE -eq 124 ]; then
      echo "✅ Completed: ${PIPELINE^^} on ${VIDEO_NAME}"
      echo "[OK] ${RUN_ID} - Completed at $(date)" >> "${SUMMARY_FILE}"
    else
      echo "❌ Failed: ${PIPELINE^^} on ${VIDEO_NAME} (exit code: $EXIT_CODE)"
      echo "[FAIL] ${RUN_ID} - Exit code $EXIT_CODE" >> "${SUMMARY_FILE}"
    fi

    # Brief pause between runs
    echo "Cooling down for 5 seconds..."
    sleep 5

  done
done

# Generate final summary
echo "" >> "${SUMMARY_FILE}"
echo "Completed: $(date)" >> "${SUMMARY_FILE}"
echo "Total runs completed: ${RUN_COUNT}" >> "${SUMMARY_FILE}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Experiment Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Results location: ${OUTPUT_DIR}/paper1/"
echo ""
echo "Files generated:"
echo "  📋 Logs:    ${OUTPUT_DIR}/logs/"
echo "  📊 Metrics: ${OUTPUT_DIR}/metrics/"
echo "  📝 Summary: ${SUMMARY_FILE}"
echo ""
echo "Next steps:"
echo "  1. Download results:"
echo "     scp -r ec2-user@EC2_IP:${OUTPUT_DIR}/paper1 ./results/"
echo ""
echo "  2. Analyze data (on local machine):"
echo "     ./process_paper1_results.sh"
echo ""

cat "${SUMMARY_FILE}"
