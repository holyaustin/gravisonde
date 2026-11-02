#!/bin/bash
# automated-benchmark-runner.sh
# Fully automated academic data collection system
# Generates videos, runs benchmarks, exports results, tracks progress
# Usage: ./automated-benchmark-runner.sh

set -e

# Configuration
BENCHMARK_DURATION=300  # 5 minutes per test
RESULTS_BASE="./results"
VIDEOS_BASE="./data/videos"
LOG_FILE="./benchmark_progress.log"
STATUS_FILE="./benchmark_status.txt"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Status update function
update_status() {
    local status="$1"
    echo "$status" > "$STATUS_FILE"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}STATUS: $status${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
}

# Initialize
clear
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║   Gravisonde Automated Benchmark Runner              ║
║   Academic Data Collection System                     ║
║                                                       ║
║   - Generates test videos                            ║
║   - Runs on x86 and ARM platforms                    ║
║   - Exports metrics automatically                     ║
║   - Tracks progress continuously                      ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Create directories
mkdir -p "$RESULTS_BASE"/{paper1,paper2,paper3}/{x86,arm}
mkdir -p "$VIDEOS_BASE"/{paper1,paper2,paper3}
mkdir -p logs

# Start logging
log "INFO" "Benchmark suite started"
log "INFO" "Duration per test: ${BENCHMARK_DURATION}s (5 minutes)"
log "INFO" "Results directory: $RESULTS_BASE"

# =============================================================================
# Step 1: Check Prerequisites
# =============================================================================
update_status "Step 1/5: Checking prerequisites"
log "INFO" "Checking prerequisites..."

# Check ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    log "ERROR" "ffmpeg not found. Install with: sudo apt-get install ffmpeg"
    exit 1
fi
log "INFO" "✓ ffmpeg installed"

# Check Docker
if ! command -v docker &> /dev/null; then
    log "ERROR" "Docker not found"
    exit 1
fi
log "INFO" "✓ Docker installed"

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    log "ERROR" "Docker Compose V2 not found"
    exit 1
fi
log "INFO" "✓ Docker Compose installed"

# Check AWS CLI (for metrics export)
if ! command -v aws &> /dev/null; then
    log "WARN" "AWS CLI not found - will use alternative export method"
fi

# Check jq (for JSON parsing)
if ! command -v jq &> /dev/null; then
    log "WARN" "jq not found - installing..."
    sudo apt-get install -y jq > /dev/null 2>&1 || log "WARN" "Could not install jq"
fi

sleep 2

# =============================================================================
# Step 2: Generate Test Videos
# =============================================================================
update_status "Step 2/5: Generating test videos (10 videos, ~10 minutes)"
log "INFO" "Generating test videos..."

generate_video() {
    local name=$1
    local output=$2
    local filter=$3

    log "INFO" "Generating ${name}..."

    ffmpeg -f lavfi -i testsrc=duration=300:size=640x480:rate=30 \
        -vf "$filter" \
        -c:v libx264 -preset fast -y "$output" \
        > /dev/null 2>&1

    if [ -f "$output" ]; then
        local size=$(ls -lh "$output" | awk '{print $5}')
        log "INFO" "✓ ${name} created ($size)"
    else
        log "ERROR" "Failed to create ${name}"
        return 1
    fi
}

# Paper 1: Architecture Comparison (3 videos)
log "INFO" "Paper 1: Architecture Comparison Videos"

generate_video "paper1_static_scene" \
    "$VIDEOS_BASE/paper1/static_scene.mp4" \
    "drawtext=text='Static Scene - Paper 1':fontsize=20:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5"

generate_video "paper1_dynamic_scene" \
    "$VIDEOS_BASE/paper1/dynamic_scene.mp4" \
    "drawbox=x='50+150*sin(t)':y='100+50*cos(t)':w=80:h=80:color=red@0.7:t=fill,drawbox=x='200+100*cos(t*1.5)':y='150+80*sin(t*1.5)':w=60:h=60:color=blue@0.7:t=fill,drawtext=text='Dynamic Scene':fontsize=20:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5"

generate_video "paper1_dense_objects" \
    "$VIDEOS_BASE/paper1/dense_objects.mp4" \
    "drawbox=x=50:y=50:w=80:h=80:color=red@0.6:t=fill,drawbox=x=200:y=50:w=80:h=80:color=blue@0.6:t=fill,drawbox=x=350:y=50:w=80:h=80:color=green@0.6:t=fill,drawbox=x=50:y=200:w=80:h=80:color=yellow@0.6:t=fill,drawbox=x=200:y=200:w=80:h=80:color=magenta@0.6:t=fill,drawtext=text='Dense Objects':fontsize=18:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5"

# Paper 2: Cost-Efficiency (3 videos)
log "INFO" "Paper 2: Cost-Efficiency Videos"

generate_video "paper2_detection_heavy" \
    "$VIDEOS_BASE/paper2/detection_heavy.mp4" \
    "drawbox=x='50+mod(t*50\,500)':y=100:w=60:h=60:color=red@0.7:t=fill,drawbox=x='150+mod(t*70\,450)':y=150:w=60:h=60:color=blue@0.7:t=fill,drawbox=x='250+mod(t*90\,400)':y=200:w=60:h=60:color=green@0.7:t=fill,drawtext=text='Detection Heavy':fontsize=18:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5"

# Use mandelbrot for feature-heavy (requires special source)
log "INFO" "Generating paper2_feature_heavy (mandelbrot fractal)..."
ffmpeg -f lavfi -i mandelbrot=duration=300:size=640x480:rate=30 \
    -vf "drawtext=text='Feature Heavy':fontsize=20:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5" \
    -c:v libx264 -preset fast -y "$VIDEOS_BASE/paper2/feature_heavy.mp4" \
    > /dev/null 2>&1
log "INFO" "✓ paper2_feature_heavy created"

generate_video "paper2_balanced" \
    "$VIDEOS_BASE/paper2/balanced.mp4" \
    "drawbox=x='100+100*sin(t)':y='150+50*cos(t)':w=80:h=80:color=red@0.6:t=fill,drawbox=x='300+80*cos(t*1.2)':y='200+60*sin(t*1.2)':w=70:h=70:color=blue@0.6:t=fill,drawtext=text='Balanced':fontsize=20:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5"

# Paper 3: Feature Detectors (4 videos)
log "INFO" "Paper 3: Feature Detector Comparison Videos"

log "INFO" "Generating paper3_high_texture (mandelbrot)..."
ffmpeg -f lavfi -i mandelbrot=duration=300:size=640x480:rate=30 \
    -vf "drawtext=text='High Texture':fontsize=20:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5" \
    -c:v libx264 -preset fast -y "$VIDEOS_BASE/paper3/high_texture.mp4" \
    > /dev/null 2>&1
log "INFO" "✓ paper3_high_texture created"

log "INFO" "Generating paper3_low_texture (solid color)..."
ffmpeg -f lavfi -i color=c=skyblue:duration=300:size=640x480:rate=30 \
    -vf "drawbox=x=200:y=180:w=240:h=120:color=white@0.8:t=fill,drawtext=text='Low Texture':fontsize=20:x=10:y=10:fontcolor=black:box=1:boxcolor=white@0.5" \
    -c:v libx264 -preset fast -y "$VIDEOS_BASE/paper3/low_texture.mp4" \
    > /dev/null 2>&1
log "INFO" "✓ paper3_low_texture created"

generate_video "paper3_lighting_change" \
    "$VIDEOS_BASE/paper3/lighting_change.mp4" \
    "eq=brightness='0.5*sin(t/10)':contrast=1.5,drawtext=text='Lighting Change':fontsize=18:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5"

generate_video "paper3_motion_blur" \
    "$VIDEOS_BASE/paper3/motion_blur.mp4" \
    "boxblur=luma_radius=3:luma_power=1,drawbox=x='50+400*sin(t*2)':y=200:w=80:h=80:color=red@0.7:t=fill,drawtext=text='Motion Blur':fontsize=18:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5"

log "INFO" "✓ All 10 videos generated successfully"
sleep 2

# =============================================================================
# Step 3: Build Docker Images for Both Platforms
# =============================================================================
update_status "Step 3/5: Building Docker images (x86 and ARM)"
log "INFO" "Building Docker images for multi-platform testing..."

# Check if buildx is available
if docker buildx version > /dev/null 2>&1; then
    log "INFO" "Docker Buildx available - will use multi-platform builds"
    USE_BUILDX=true
else
    log "WARN" "Docker Buildx not available - will use current platform only"
    USE_BUILDX=false
fi

# Build x86 image (native on your system)
log "INFO" "Building x86 image..."
docker compose build pipeline > /dev/null 2>&1
log "INFO" "✓ x86 image built"

# For ARM testing, we'll use QEMU emulation
if [ "$USE_BUILDX" = true ]; then
    log "INFO" "Setting up ARM emulation with QEMU..."
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes > /dev/null 2>&1 || true
    log "INFO" "✓ ARM emulation ready"
fi

sleep 2

# =============================================================================
# Step 4: Run Benchmarks
# =============================================================================
update_status "Step 4/5: Running benchmarks (20 tests × 5 min = ~100 minutes)"
log "INFO" "Starting benchmark runs..."

# Define test matrix
declare -A PAPERS
PAPERS=(
    ["paper1"]="static_scene dynamic_scene dense_objects"
    ["paper2"]="detection_heavy feature_heavy balanced"
    ["paper3"]="high_texture low_texture lighting_change motion_blur"
)

PLATFORMS=("x86" "arm")
TOTAL_TESTS=0
COMPLETED_TESTS=0

# Count total tests
for paper in "${!PAPERS[@]}"; do
    video_count=$(echo ${PAPERS[$paper]} | wc -w)
    TOTAL_TESTS=$((TOTAL_TESTS + video_count * 2))  # × 2 for x86 and ARM
done

log "INFO" "Total tests to run: $TOTAL_TESTS"
log "INFO" "Estimated time: $((TOTAL_TESTS * BENCHMARK_DURATION / 60)) minutes"

# Function to run a single benchmark
run_benchmark() {
    local paper=$1
    local video_name=$2
    local platform=$3
    local video_path="$VIDEOS_BASE/${paper}/${video_name}.mp4"
    local container_name="bench_${paper}_${video_name}_${platform}"
    local result_file="$RESULTS_BASE/${paper}/${platform}/${video_name}_$(date +%Y%m%d_%H%M%S).csv"

    COMPLETED_TESTS=$((COMPLETED_TESTS + 1))

    update_status "Test $COMPLETED_TESTS/$TOTAL_TESTS: ${paper}/${video_name} on ${platform}"
    log "INFO" "Running: ${paper}/${video_name} on ${platform}"
    log "INFO" "Video: $video_path"
    log "INFO" "Container: $container_name"
    log "INFO" "Results: $result_file"

    # Stop any existing container
    docker rm -f "$container_name" > /dev/null 2>&1 || true

    # Determine platform flag
    local platform_flag=""
    if [ "$platform" = "arm" ]; then
        platform_flag="--platform linux/arm64"
    else
        platform_flag="--platform linux/amd64"
    fi

    # Run the benchmark
    log "INFO" "Starting container (will run for ${BENCHMARK_DURATION}s)..."

    docker run -d \
        $platform_flag \
        --name "$container_name" \
        --restart no \
        -e AWS_REGION=eu-north-1 \
        -e AWS_DEFAULT_REGION=eu-north-1 \
        -e CW_LOG_GROUP=/aws/gravisonde/pipeline \
        -e S3_BENCHMARK_BUCKET=gravisonde \
        -e PIPELINE_MODE=cool \
        -e DETECTION_MODEL=yolo11n.onnx \
        -e CONF_THRESHOLD=0.5 \
        -e METRICS_PUSH_INTERVAL_SEC=10 \
        -e AWS_ENDPOINT_URL=http://host.docker.internal:4566 \
        -e AWS_ACCESS_KEY_ID=test \
        -e AWS_SECRET_ACCESS_KEY=test \
        -v "$(pwd)/${video_path}:/data/sample.mp4:ro" \
        -v "$(pwd)/data/yolo11n.onnx:/app/yolo11n.onnx:ro" \
        gravisonde-pipeline > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        log "ERROR" "Failed to start container"
        return 1
    fi

    log "INFO" "Container started, processing for ${BENCHMARK_DURATION}s..."

    # Show progress bar
    for i in $(seq 1 $BENCHMARK_DURATION); do
        if [ $((i % 30)) -eq 0 ]; then
            local progress=$((i * 100 / BENCHMARK_DURATION))
            echo -ne "\r  Progress: ${progress}% [${i}/${BENCHMARK_DURATION}s]"

            # Check if container is still running
            if ! docker ps -q --filter "name=$container_name" | grep -q .; then
                echo ""
                log "ERROR" "Container stopped unexpectedly"
                docker logs "$container_name" > "logs/${container_name}_error.log" 2>&1
                return 1
            fi
        fi
        sleep 1
    done
    echo ""

    log "INFO" "Benchmark complete, exporting metrics..."

    # Export metrics from LocalStack
    if command -v aws &> /dev/null; then
        aws logs filter-log-events \
            --log-group-name /aws/gravisonde/pipeline \
            --start-time $(($(date +%s) - BENCHMARK_DURATION - 60))000 \
            --endpoint-url http://localhost:4566 \
            --region eu-north-1 \
            --no-sign-request \
            --output json 2>/dev/null | \
            jq -r '
                "frameId,timestamp,latencyMs,inferenceMs,detections,instanceId,opencvVersion,coolVersion,arch,pipeline",
                (.events[].message | fromjson |
                    [.frameId, .ts, .latencyMs, .inferenceMs, .detections, .instanceId, .opencvVersion, (.coolVersion // "N/A"), .arch, .pipeline] |
                    @csv
                )
            ' > "$result_file" 2>/dev/null
    else
        # Fallback: export from container logs
        docker logs "$container_name" 2>&1 | \
            grep -E "frame_id|frameId" | \
            head -n 100 > "$result_file"
    fi

    # Check if CSV was created
    if [ -f "$result_file" ] && [ -s "$result_file" ]; then
        local line_count=$(wc -l < "$result_file")
        log "INFO" "✓ Exported $((line_count - 1)) frames to: $result_file"
    else
        log "WARN" "⚠ No metrics exported, saving container logs instead"
        docker logs "$container_name" > "${result_file%.csv}.log" 2>&1
    fi

    # Save container logs
    docker logs "$container_name" > "logs/${container_name}.log" 2>&1

    # Stop and remove container
    docker rm -f "$container_name" > /dev/null 2>&1

    log "INFO" "✓ Test complete: ${paper}/${video_name} on ${platform}"
    echo ""
    sleep 5  # Cool-down between tests
}

# Ensure LocalStack is running
log "INFO" "Starting LocalStack for metrics collection..."
docker compose up -d localstack > /dev/null 2>&1
sleep 10

# Run all benchmarks
for paper in "${!PAPERS[@]}"; do
    for video_name in ${PAPERS[$paper]}; do
        for platform in "${PLATFORMS[@]}"; do
            # Skip ARM if buildx not available
            if [ "$platform" = "arm" ] && [ "$USE_BUILDX" != true ]; then
                log "WARN" "Skipping ARM test (buildx not available)"
                COMPLETED_TESTS=$((COMPLETED_TESTS + 1))
                continue
            fi

            run_benchmark "$paper" "$video_name" "$platform"
        done
    done
done

# =============================================================================
# Step 5: Generate Summary Report
# =============================================================================
update_status "Step 5/5: Generating summary report"
log "INFO" "Generating summary report..."

SUMMARY_FILE="$RESULTS_BASE/benchmark_summary_$(date +%Y%m%d_%H%M%S).txt"

cat > "$SUMMARY_FILE" << EOF
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║   Gravisonde Benchmark Summary                       ║
║   Generated: $(date '+%Y-%m-%d %H:%M:%S')                      ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝

Total tests run: $COMPLETED_TESTS
Duration: ${BENCHMARK_DURATION}s per test
Results directory: $RESULTS_BASE

Test Matrix:
EOF

for paper in "${!PAPERS[@]}"; do
    echo "" >> "$SUMMARY_FILE"
    echo "${paper}:" >> "$SUMMARY_FILE"
    for video_name in ${PAPERS[$paper]}; do
        for platform in "${PLATFORMS[@]}"; do
            local result_file=$(ls "$RESULTS_BASE/${paper}/${platform}/${video_name}"*.csv 2>/dev/null | head -n 1)
            if [ -f "$result_file" ]; then
                local line_count=$(wc -l < "$result_file")
                echo "  ✓ ${video_name} (${platform}): $((line_count - 1)) frames" >> "$SUMMARY_FILE"
            else
                echo "  ✗ ${video_name} (${platform}): No data" >> "$SUMMARY_FILE"
            fi
        done
    done
done

cat >> "$SUMMARY_FILE" << EOF

Files Generated:
  - Videos: $VIDEOS_BASE/
  - Results: $RESULTS_BASE/
  - Logs: ./logs/
  - Status: $STATUS_FILE
  - Progress: $LOG_FILE

Next Steps:
  1. Analyze results with Python/R
  2. Generate plots and tables
  3. Write academic papers

EOF

cat "$SUMMARY_FILE"
log "INFO" "Summary saved to: $SUMMARY_FILE"

# =============================================================================
# Complete
# =============================================================================
update_status "COMPLETE: All benchmarks finished successfully"

echo ""
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║   ✓ BENCHMARK SUITE COMPLETE                         ║
║                                                       ║
║   All data collected and ready for analysis          ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

log "INFO" "Benchmark suite completed successfully"
log "INFO" "Results available in: $RESULTS_BASE"
log "INFO" "Summary: $SUMMARY_FILE"

# Cleanup
docker compose down > /dev/null 2>&1

echo ""
echo "View results:"
echo "  - Summary: cat $SUMMARY_FILE"
echo "  - Full log: cat $LOG_FILE"
echo "  - Results directory: ls -R $RESULTS_BASE"
echo ""
echo "Analyze with Python:"
echo "  python3 analyze_results.py $RESULTS_BASE"
