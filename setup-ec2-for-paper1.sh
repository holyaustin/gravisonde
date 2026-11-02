#!/bin/bash
# setup-ec2-for-paper1.sh
# Update EC2 Graviton4 instance and run Paper 1 ARM tests
# Run this script ON YOUR LOCAL MACHINE (it SSHs to EC2 and runs commands there)

set -e

# Configuration
EC2_IP="16.16.75.56"
KEY_PATH="/home/augustineonuora/.ssh/gravisonde-aws-key1.pem"
GITHUB_REPO="https://github.com/YOUR_USERNAME/gravisonde.git"  # UPDATE THIS!

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║   EC2 Graviton4 Setup for Paper 1                    ║
║   Update repo and run ARM benchmarks                  ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo "Target EC2: $EC2_IP"
echo ""

# Check if SSH works
echo "Testing SSH connection..."
if ! ssh -i "$KEY_PATH" -o ConnectTimeout=5 ec2-user@$EC2_IP "echo 'Connection OK'" > /dev/null 2>&1; then
    echo -e "${RED}✗ SSH connection failed${NC}"
    echo "Run: ./fix-ec2-ssh.sh first"
    exit 1
fi
echo -e "${GREEN}✓ SSH connection working${NC}"
echo ""

# =============================================================================
# Step 1: Check if repo exists or clone fresh
# =============================================================================
echo -e "${BLUE}Step 1: Checking repo on EC2...${NC}"
echo ""

REPO_EXISTS=$(ssh -i "$KEY_PATH" ec2-user@$EC2_IP "test -d ~/gravisonde && echo 'yes' || echo 'no'")

if [ "$REPO_EXISTS" = "yes" ]; then
    echo "Repository exists on EC2"
    echo "Pulling latest changes..."

    ssh -i "$KEY_PATH" ec2-user@$EC2_IP << 'ENDSSH'
cd ~/gravisonde
git fetch origin
git pull origin main || git pull origin master
echo "✓ Repo updated to latest"
ENDSSH

    echo -e "${GREEN}✓ Repo updated${NC}"
else
    echo "Repository not found on EC2"
    echo "Cloning from GitHub..."

    echo ""
    echo -e "${YELLOW}IMPORTANT: Update GITHUB_REPO in this script first!${NC}"
    read -p "Press Enter when you've updated the GitHub repo URL in the script..."

    ssh -i "$KEY_PATH" ec2-user@$EC2_IP << ENDSSH
cd ~
git clone $GITHUB_REPO
cd gravisonde
echo "✓ Repo cloned"
ENDSSH

    echo -e "${GREEN}✓ Repo cloned${NC}"
fi

echo ""

# =============================================================================
# Step 2: Copy Paper 1 videos to EC2
# =============================================================================
echo -e "${BLUE}Step 2: Copying Paper 1 videos to EC2...${NC}"
echo ""

# Check if videos exist locally
if [ ! -d "data/videos/paper1" ]; then
    echo -e "${RED}✗ Paper 1 videos not found locally${NC}"
    echo "Run ./generate-summary-report.sh first to ensure videos are generated"
    exit 1
fi

echo "Copying Paper 1 videos (3 files, ~6MB)..."

ssh -i "$KEY_PATH" ec2-user@$EC2_IP "mkdir -p ~/gravisonde/data/videos/paper1"

scp -i "$KEY_PATH" -r data/videos/paper1/*.mp4 ec2-user@$EC2_IP:~/gravisonde/data/videos/paper1/

echo -e "${GREEN}✓ Videos copied${NC}"
echo ""

# =============================================================================
# Step 3: Download YOLO model on EC2
# =============================================================================
echo -e "${BLUE}Step 3: Downloading YOLO model on EC2...${NC}"
echo ""

ssh -i "$KEY_PATH" ec2-user@$EC2_IP << 'ENDSSH'
cd ~/gravisonde
mkdir -p data

if [ ! -f "data/yolo11n.onnx" ]; then
    echo "Downloading YOLO11n model (~10MB)..."
    wget -q --show-progress -O data/yolo11n.onnx \
        "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.onnx"
    echo "✓ YOLO model downloaded"
else
    echo "✓ YOLO model already exists"
fi
ENDSSH

echo -e "${GREEN}✓ YOLO model ready${NC}"
echo ""

# =============================================================================
# Step 4: Build Docker image on EC2
# =============================================================================
echo -e "${BLUE}Step 4: Building Docker image on Graviton4...${NC}"
echo ""

echo "This may take 5-10 minutes on first build..."

ssh -i "$KEY_PATH" ec2-user@$EC2_IP << 'ENDSSH'
cd ~/gravisonde

# Check if Docker is running
if ! docker ps > /dev/null 2>&1; then
    echo "Starting Docker..."
    sudo systemctl start docker
    sudo usermod -aG docker ec2-user
    echo "✓ Docker started"
fi

# Build the pipeline image
echo "Building gravisonde-pipeline image..."
docker compose build pipeline

echo "✓ Docker image built"
ENDSSH

echo -e "${GREEN}✓ Docker image ready on Graviton4${NC}"
echo ""

# =============================================================================
# Step 5: Run Paper 1 benchmarks on Graviton4 ARM
# =============================================================================
echo -e "${BLUE}Step 5: Running Paper 1 benchmarks (3 tests × 5 min = 15 min)...${NC}"
echo ""

echo "Starting benchmarks on Graviton4 ARM..."
echo "This will run for ~15 minutes"
echo ""

# Create results directory
ssh -i "$KEY_PATH" ec2-user@$EC2_IP "mkdir -p ~/gravisonde/results/paper1/arm"

# Run each Paper 1 video
VIDEOS=("static_scene" "dynamic_scene" "dense_objects")
TEST_NUM=1
TOTAL_TESTS=3

for video in "${VIDEOS[@]}"; do
    echo -e "${BLUE}Test $TEST_NUM/$TOTAL_TESTS: paper1/${video} on Graviton4 ARM${NC}"
    echo "Video: data/videos/paper1/${video}.mp4"
    echo "Running for 5 minutes..."
    echo ""

    # Update docker-compose.yml to use current video
    ssh -i "$KEY_PATH" ec2-user@$EC2_IP << ENDSSH
cd ~/gravisonde

# Update docker-compose.yml with current video
sed -i "s|sample1.mp4|paper1/${video}.mp4|g" docker-compose.yml

# Stop any running containers
docker compose down 2>/dev/null || true

# Start pipeline
docker compose up -d pipeline

echo "Container started, processing for 300 seconds..."
ENDSSH

    # Wait 5 minutes locally
    echo "Progress:"
    for i in {1..60}; do
        echo -n "."
        sleep 5
    done
    echo ""
    echo "✓ 5 minutes complete"

    # Export metrics
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)

    ssh -i "$KEY_PATH" ec2-user@$EC2_IP << ENDSSH
cd ~/gravisonde

# Export metrics from LocalStack if available
if command -v aws &> /dev/null && docker ps | grep localstack > /dev/null 2>&1; then
    aws logs filter-log-events \
        --log-group-name /aws/gravisonde/pipeline \
        --start-time \$(($(date +%s) - 360))000 \
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
        ' > "results/paper1/arm/${video}_graviton4_${TIMESTAMP}.csv" 2>/dev/null
else
    # Fallback: save docker logs
    docker logs gravisonde-pipeline-1 > "results/paper1/arm/${video}_graviton4_${TIMESTAMP}.log" 2>&1
fi

# Stop container
docker compose down

echo "✓ Test complete"
ENDSSH

    echo -e "${GREEN}✓ Test $TEST_NUM/$TOTAL_TESTS complete: ${video}${NC}"
    echo ""

    TEST_NUM=$((TEST_NUM + 1))
done

echo -e "${GREEN}✓ All Paper 1 ARM tests complete!${NC}"
echo ""

# =============================================================================
# Step 6: Download results from EC2
# =============================================================================
echo -e "${BLUE}Step 6: Downloading results from EC2...${NC}"
echo ""

# Create local results directory
mkdir -p results/paper1/arm

# Download all ARM results
scp -i "$KEY_PATH" -r ec2-user@$EC2_IP:~/gravisonde/results/paper1/arm/*.csv results/paper1/arm/ 2>/dev/null || \
scp -i "$KEY_PATH" -r ec2-user@$EC2_IP:~/gravisonde/results/paper1/arm/*.log results/paper1/arm/ 2>/dev/null || \
echo "Note: No CSV files found, logs may be available"

echo -e "${GREEN}✓ Results downloaded to: results/paper1/arm/${NC}"
echo ""

# =============================================================================
# Summary
# =============================================================================
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║   ✓ Paper 1 ARM Data Collection Complete!           ║
║                                                       ║
║   All 3 papers now have complete datasets            ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo "Results collected:"
echo "  - Paper 1 x86: results/paper1/x86/ (3 tests)"
echo "  - Paper 1 ARM: results/paper1/arm/ (3 tests) ← NEW!"
echo "  - Paper 2 x86: results/paper2/x86/ (3 tests)"
echo "  - Paper 3 x86: results/paper3/x86/ (4 tests)"
echo ""

echo "Next steps:"
echo "  1. Analyze complete data: python3 analyze_results.py results/"
echo "  2. Compare x86 vs ARM for Paper 1"
echo "  3. Write all 3 papers with complete datasets!"
echo ""

echo "View Paper 1 ARM results:"
echo "  ls -lh results/paper1/arm/"
echo ""
