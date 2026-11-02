#!/bin/bash
# Gravisonde Local Setup - Automated Script
# Usage: ./run-local.sh

set -e

echo "=========================================="
echo "Gravisonde Local Setup"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Change to script directory
cd "$(dirname "$0")"

echo "Step 1: Checking prerequisites..."
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not found. Please install Docker first.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker installed: $(docker --version)${NC}"

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    echo -e "${RED}✗ Docker Compose not found. Please install Docker Compose V2.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose installed: $(docker compose version)${NC}"

# Check if Docker daemon is running
if ! docker ps &> /dev/null; then
    echo -e "${RED}✗ Docker daemon is not running. Please start Docker.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker daemon is running${NC}"
echo ""

echo "Step 2: Checking video file..."
echo ""

# Check if sample video exists
if [ ! -f "data/sample1.mp4" ] || [ ! -s "data/sample1.mp4" ]; then
    echo -e "${YELLOW}⚠ Sample video not found or empty${NC}"

    # Check if ffmpeg is available
    if command -v ffmpeg &> /dev/null; then
        echo "Generating test video with ffmpeg..."
        mkdir -p data
        ffmpeg -f lavfi -i testsrc=duration=30:size=640x480:rate=30 \
            -c:v libx264 -preset fast data/sample1.mp4 -y 2>&1 | grep -v "frame=" || true
        echo -e "${GREEN}✓ Test video generated: data/sample1.mp4${NC}"
    else
        echo -e "${RED}✗ ffmpeg not found and no sample video available${NC}"
        echo "Please either:"
        echo "  1. Install ffmpeg: sudo apt-get install ffmpeg"
        echo "  2. Place a video file at: data/sample1.mp4"
        exit 1
    fi
else
    VIDEO_SIZE=$(ls -lh data/sample1.mp4 | awk '{print $5}')
    echo -e "${GREEN}✓ Video file found: data/sample1.mp4 ($VIDEO_SIZE)${NC}"
fi
echo ""

echo "Step 3: Checking YOLO model..."
echo ""

# Check if YOLO model exists
if [ ! -f "data/yolo11n.onnx" ] || [ ! -s "data/yolo11n.onnx" ]; then
    echo -e "${YELLOW}⚠ YOLO model not found${NC}"

    # Check if wget is available
    if command -v wget &> /dev/null; then
        echo "Downloading YOLO11n model (~10MB)..."
        mkdir -p data
        wget -q --show-progress -O data/yolo11n.onnx \
            "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.onnx" || {
            echo -e "${RED}✗ Failed to download YOLO model${NC}"
            exit 1
        }
        echo -e "${GREEN}✓ YOLO model downloaded: data/yolo11n.onnx${NC}"
    else
        echo -e "${RED}✗ wget not found and no YOLO model available${NC}"
        echo "Please download manually:"
        echo "  wget -O data/yolo11n.onnx https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.onnx"
        exit 1
    fi
else
    MODEL_SIZE=$(ls -lh data/yolo11n.onnx | awk '{print $5}')
    echo -e "${GREEN}✓ YOLO model found: data/yolo11n.onnx ($MODEL_SIZE)${NC}"
fi
echo ""

echo "Step 4: Starting Docker Compose stack..."
echo ""

# Stop any existing containers
if docker compose ps -q 2>/dev/null | grep -q .; then
    echo "Stopping existing containers..."
    docker compose down
fi

# Start the stack
echo "Building and starting services (this may take a few minutes on first run)..."
docker compose up --build -d

# Wait for services to be healthy
echo ""
echo "Waiting for services to start..."
sleep 5

# Check if containers are running
RUNNING=$(docker compose ps --format json 2>/dev/null | jq -r '.State' | grep -c "running" || echo "0")
TOTAL=$(docker compose ps --format json 2>/dev/null | wc -l)

if [ "$RUNNING" -lt 3 ]; then
    echo -e "${YELLOW}⚠ Some containers may not be running yet${NC}"
    echo "Check status with: docker compose ps"
    echo "View logs with: docker compose logs -f"
else
    echo -e "${GREEN}✓ All containers are running${NC}"
fi
echo ""

echo "Step 5: Checking pipeline logs..."
echo ""

# Show first few lines of pipeline logs
sleep 3
docker compose logs --tail=10 pipeline | grep -E "INFO|WARNING|ERROR" || echo "Waiting for pipeline to start..."
echo ""

echo "=========================================="
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Access the dashboard at: ${GREEN}http://localhost:3000${NC}"
echo ""
echo "Useful commands:"
echo "  - View live logs:       docker compose logs -f pipeline"
echo "  - View all logs:        docker compose logs"
echo "  - Check status:         docker compose ps"
echo "  - Stop services:        docker compose down"
echo "  - Restart pipeline:     docker compose restart pipeline"
echo ""
echo "Troubleshooting:"
echo "  - If dashboard is not loading, check logs: docker compose logs dashboard"
echo "  - If pipeline errors, check: docker compose logs pipeline"
echo "  - If port 3000 is busy, edit docker-compose.yml to use a different port"
echo ""
echo "Press Ctrl+C to stop watching logs, or run in another terminal:"
echo "  docker compose logs -f"
echo ""

# Optionally open browser (uncomment if you want)
# if command -v xdg-open &> /dev/null; then
#     echo "Opening dashboard in browser..."
#     sleep 2
#     xdg-open http://localhost:3000 &> /dev/null &
# fi

# Watch logs
echo "Watching pipeline logs (Ctrl+C to exit)..."
echo ""
docker compose logs -f pipeline
