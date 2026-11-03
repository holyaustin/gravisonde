#!/bin/bash
# Gravisonde Benchmark Runner
# Runs COOL and Stock pipelines sequentially and exports CSV results

set -e

DURATION=${1:-300}  # Default 5 minutes
OUTPUT_DIR="/home/ec2-user/gravisonde/results"

echo "🚀 Gravisonde Benchmark Experiment"
echo "=================================="
echo "Duration: ${DURATION} seconds per run"
echo "Output: ${OUTPUT_DIR}"
echo ""

# Create results directory
mkdir -p "${OUTPUT_DIR}"

# Stop any running pipeline
echo "Stopping existing pipeline..."
docker-compose -f docker-compose.ec2.yml down 2>/dev/null || true

# Run COOL benchmark
echo ""
echo "📊 Running COOL pipeline benchmark..."
echo "Started at: $(date)"

docker run --rm \
  --cpus 1.5 \
  -v $(pwd)/data/sample1.mp4:/data/sample.mp4:ro \
  -v $(pwd)/data/yolo11n.onnx:/app/yolo11n.onnx:ro \
  -v ${OUTPUT_DIR}:/results \
  -e VIDEO_SOURCE=/data/sample.mp4 \
  -e PIPELINE_MODE=cool \
  -e DETECTION_MODEL=yolo11n.onnx \
  -e CONF_THRESHOLD=0.5 \
  -e METRICS_PUSH_INTERVAL_SEC=1 \
  -e INSTANCE_TYPE=c8g.xlarge \
  -e ARCH=graviton \
  -e OPENCV_VERSION=5.0.0.93 \
  gravisonde-pipeline:latest \
  timeout ${DURATION} python -m src.pipeline.main \
    --duration ${DURATION} \
    --pipeline cool \
    --arch graviton \
    --instance-type c8g.xlarge \
    2>&1 | tee ${OUTPUT_DIR}/cool_run.log

echo "✅ COOL benchmark complete"
echo ""

# Wait a bit before next run
sleep 10

# Run Stock benchmark
echo "📊 Running Stock pipeline benchmark..."
echo "Started at: $(date)"

docker run --rm \
  --cpus 1.5 \
  -v $(pwd)/data/sample1.mp4:/data/sample.mp4:ro \
  -v $(pwd)/data/yolo11n.onnx:/app/yolo11n.onnx:ro \
  -v ${OUTPUT_DIR}:/results \
  -e VIDEO_SOURCE=/data/sample.mp4 \
  -e PIPELINE_MODE=stock \
  -e DETECTION_MODEL=yolo11n.onnx \
  -e CONF_THRESHOLD=0.5 \
  -e METRICS_PUSH_INTERVAL_SEC=1 \
  -e INSTANCE_TYPE=c8g.xlarge \
  -e ARCH=graviton \
  -e OPENCV_VERSION=5.0.0.93 \
  gravisonde-pipeline:latest \
  timeout ${DURATION} python -m src.pipeline.main \
    --duration ${DURATION} \
    --pipeline stock \
    --arch graviton \
    --instance-type c8g.xlarge \
    2>&1 | tee ${OUTPUT_DIR}/stock_run.log

echo "✅ Stock benchmark complete"
echo ""

# Summary
echo "=================================="
echo "🎉 Benchmark experiment complete!"
echo "Results location: ${OUTPUT_DIR}"
echo ""
echo "Files generated:"
ls -lh ${OUTPUT_DIR}
echo ""
echo "To download results:"
echo "  scp -i ~/.ssh/gravisonde-aws-key1.pem -r ec2-user@16.16.75.56:${OUTPUT_DIR} ."
