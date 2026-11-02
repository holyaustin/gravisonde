# Quick Start (Choose One Method)

Method 1: Automated Script (Easiest)

cd /home/augustineonuora/Dapps-Empty/2026/Oct2026/gravisonde

# Make script executable
chmod +x run-local.sh

# Run it (handles everything automatically)
./run-local.sh

The script will:
- ✅ Check Docker is installed and running
- ✅ Download YOLO model if missing (~10MB)
- ✅ Generate test video if missing
- ✅ Start all services (dashboard, pipeline, LocalStack)
- ✅ Show you the logs

Method 2: Manual Steps

cd /home/augustineonuora/Dapps-Empty/2026/Oct2026/gravisonde

# 1. Download YOLO model (if not already done)
wget -O data/yolo11n.onnx \
  "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.onnx"

# 2. Ensure video exists
ls -lh data/sample1.mp4

# 3. Start everything
make local-up
# OR: docker compose up --build -d

# 4. Open browser
xdg-open http://localhost:3000

# 5. Watch logs
docker compose logs -f pipeline

What You'll See

Dashboard at http://localhost:3000 will show:
- 📊 Live FPS (frames per second)
- ⏱️ Latency metrics (P50, P95, P99)
- 🎯 Detection counts per frame
- 💰 Cost efficiency (FPS per dollar)
- 📈 Real-time charts
- 💾 Download CSV button for raw data

Expected Pipeline Logs:
✅ Detector initialized: DNN=yolo11n.onnx, Feature=aliked
✅ Connected to /data/sample.mp4 (640x480@30fps)
✅ Metrics emitter started

How to Retrieve Metrics

1. Dashboard (Primary) - Visual

Open http://localhost:3000 - all metrics shown in real-time

2. Download CSV

Click "Download Benchmark" button in dashboard to get:
csv
frame_id,ts,latency_ms,inference_ms,detections,...
0,1730498400123,45.2,42.1,3,...
1,1730498400156,43.8,41.5,3,...

3. Query LocalStack (Programmatic)

# Get CloudWatch Logs
aws logs tail /aws/gravisonde/pipeline \
  --endpoint-url http://localhost:4566 \
  --region eu-north-1 \
  --no-sign-request

# Get metrics
aws cloudwatch get-metric-statistics \
  --namespace Gravisonde/Pipeline \
  --metric-name FPS \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average \
  --endpoint-url http://localhost:4566 \
  --region eu-north-1 \
  --no-sign-request

4. Container Logs

# View all metrics in logs
docker compose logs pipeline | grep -i "frame\|fps\|latency"

# Save to file
docker compose logs pipeline > metrics_$(date +%Y%m%d_%H%M%S).log

Useful Commands

# Check if running
docker compose ps

# Stop everything
docker compose down

# Restart just the pipeline
docker compose restart pipeline

# View dashboard logs
docker compose logs dashboard

# Stop and clean all data
docker compose down -v

Troubleshooting

If you see "Model file not found":
# Download model
wget -O data/yolo11n.onnx \
  "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.onnx"

# Restart
docker compose restart pipeline

Full troubleshooting guide is in LOCAL_SETUP_GUIDE.md.

Why Local is Better Right Now

✅ No SSH issues
✅ No AWS Security Group configuration
✅ No CloudWatch Metrics SCP blocks
✅ All metrics visible immediately
✅ Fast iteration and testing
✅ No AWS costs

Once you fix the EC2 SSH issue (security group port 22), you can deploy to AWS for the real Graviton4 + COOL benchmark.



# Manual Gravisonde Local Setup Guide - Complete Walkthrough

**Date:** 2026-11-01  
**Purpose:** Run the complete Gravisonde pipeline locally and view metrics in the dashboard

## Overview

The local setup uses Docker Compose to run:
- ✅ **Dashboard** (Next.js) at http://localhost:3000
- ✅ **Pipeline** (OpenCV 5 + YOLO) processing video
- ✅ **LocalStack** (Mock AWS) for CloudWatch/S3 - **no AWS credentials needed**

All metrics are visible in real-time on the dashboard at http://localhost:3000.

---

## Prerequisites

Make sure you have these installed:

```bash
# Check Docker
docker --version
# Should be >= 24.0

# Check Docker Compose
docker compose version
# Should be v2.x

# Check if Docker daemon is running
docker ps
```

If Docker is not installed:
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install docker.io docker-compose-v2

# Add yourself to docker group (avoids needing sudo)
sudo usermod -aG docker $USER
newgrp docker
```

---

## Step-by-Step Local Setup

### Step 1: Check Video File

The pipeline needs a video file to process:

```bash
cd /home/augustineonuora/Dapps-Empty/2026/Oct2026/gravisonde

# Check if sample video exists and is not empty
ls -lh data/sample1.mp4

# If file is missing or 0 bytes, generate a test video:
ffmpeg -f lavfi -i testsrc=duration=30:size=640x480:rate=30 \
  -c:v libx264 -preset fast data/sample1.mp4

# OR use existing video
ls -lh data/*.mp4
```

### Step 2: Update docker-compose.yml (YOLO Model Mount)

The local setup needs the YOLO model mounted. Let me check the current docker-compose:

```bash
# Check current docker-compose configuration
cat docker-compose.yml | grep -A5 "pipeline:"
```

We need to ensure the YOLO model is mounted. Update the `pipeline` service volumes:

```yaml
pipeline:
  # ... existing config ...
  volumes:
    - ./data/sample1.mp4:/data/sample.mp4:ro
    # Add this line to mount YOLO model:
    - ./data/yolo11n.onnx:/app/yolo11n.onnx:ro
```

### Step 3: Download YOLO Model (if not already present)

```bash
# Check if model exists
ls -lh data/yolo11n.onnx

# If not present, download it
wget -O data/yolo11n.onnx \
  "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.onnx"

# Verify download (should be ~10.4 MB)
ls -lh data/yolo11n.onnx
```

### Step 4: Start the Local Stack

```bash
cd /home/augustineonuora/Dapps-Empty/2026/Oct2026/gravisonde

# Start all services (dashboard, pipeline, localstack)
make local-up

# OR directly with docker compose:
docker compose up --build -d
```

**Expected output:**
```
[+] Building 45.2s (24/24) FINISHED
[+] Running 3/3
 ✔ Container gravisonde-localstack-1   Started
 ✔ Container gravisonde-pipeline-1     Started  
 ✔ Container gravisonde-dashboard-1    Started

Local stack running:
  Dashboard:  http://localhost:3000
  LocalStack: http://localhost:4566
  Pipeline logs: docker compose logs -f pipeline
```

### Step 5: Verify Services Are Running

```bash
# Check all containers are up
docker compose ps

# Should show:
# NAME                      STATUS    PORTS
# gravisonde-dashboard-1    Up        0.0.0.0:3000->3000/tcp
# gravisonde-localstack-1   Up        0.0.0.0:4566->4566/tcp
# gravisonde-pipeline-1     Up        N/A
```

### Step 6: Check Pipeline Logs

```bash
# Watch pipeline logs in real-time
docker compose logs -f pipeline

# Look for these SUCCESS indicators:
# ✅ "Detector initialized: DNN=yolo11n.onnx, Feature=aliked"
# ✅ "Connected to /data/sample.mp4 (640x480@30fps)"
# ✅ "Metrics emitter started"
# ✅ NO "Model file ... not found" warnings
```

**Good output example:**
```
pipeline-1  | 2026-11-01 22:15:00,123 INFO __main__: Starting Gravisonde pipeline: cool on graviton (c8g.xlarge)
pipeline-1  | 2026-11-01 22:15:00,124 INFO src.pipeline.metrics: Metrics emitter started
pipeline-1  | 2026-11-01 22:15:00,125 INFO src.pipeline.capture: Connected to /data/sample.mp4 (640x480@30fps)
pipeline-1  | 2026-11-01 22:15:00,200 INFO src.pipeline.detection: Detector initialized: DNN=yolo11n.onnx, Feature=aliked
```

### Step 7: Open Dashboard and View Metrics

Open your browser and go to:
```
http://localhost:3000
```

**You should see:**
- 📊 **Live Metrics Cards** showing:
  - FPS (frames per second)
  - Latency P50/P95/P99 (milliseconds)
  - Detections per frame
  - FPS per dollar (cost efficiency)
- 📹 **Video feed** with bounding box overlays
- 📈 **Real-time charts** updating every few seconds
- 💾 **Download Benchmark** button to get CSV data

---

## Retrieving Metrics

### Method 1: View in Dashboard (Primary)

The dashboard at http://localhost:3000 shows all metrics in real-time.

### Method 2: Export CSV from Dashboard

Click the **"Download Benchmark"** button in the dashboard to get a CSV with:
```csv
frame_id,ts,latency_ms,inference_ms,detections,instance_id,opencv_version,arch,pipeline
0,1730498100123,45.2,42.1,3,gravisonde-demo,5.0.0.93,graviton,cool
1,1730498100156,43.8,41.5,3,gravisonde-demo,5.0.0.93,graviton,cool
...
```

### Method 3: Query LocalStack Directly

LocalStack stores all metrics in its in-memory CloudWatch:

```bash
# Get CloudWatch Logs
aws logs tail /aws/gravisonde/pipeline \
  --follow \
  --endpoint-url http://localhost:4566 \
  --region eu-north-1 \
  --no-sign-request

# Get CloudWatch Metrics
aws cloudwatch get-metric-statistics \
  --namespace Gravisonde/Pipeline \
  --metric-name FPS \
  --dimensions Name=InstanceId,Value=gravisonde-demo \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average \
  --endpoint-url http://localhost:4566 \
  --region eu-north-1 \
  --no-sign-request
```

### Method 4: Access Container Logs

```bash
# View all pipeline logs
docker compose logs pipeline

# Save logs to file
docker compose logs pipeline > pipeline_metrics.log

# Filter for specific metrics
docker compose logs pipeline | grep "Pushed.*metrics"
```

### Method 5: Execute Python in Container

```bash
# Access Python metrics collector directly
docker compose exec pipeline python -c "
from src.pipeline.metrics import get_collector
collector = get_collector()
if collector:
    stats = collector.get_current_stats()
    print(stats)
"
```

---

## Troubleshooting

### Issue 1: "Model file not found"

**Symptom:**
```
WARNING src.pipeline.detection: Model file yolo11n.onnx not found, using dummy detector
```

**Fix:**
```bash
# Download model
wget -O data/yolo11n.onnx \
  "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.onnx"

# Update docker-compose.yml to mount it
# Add under pipeline.volumes:
#   - ./data/yolo11n.onnx:/app/yolo11n.onnx:ro

# Restart
docker compose down
docker compose up -d
```

### Issue 2: "Cannot open video source"

**Symptom:**
```
ERROR __main__: Cannot open video source: /data/sample.mp4
```

**Fix:**
```bash
# Generate test video
ffmpeg -f lavfi -i testsrc=duration=30:size=640x480:rate=30 \
  -c:v libx264 -preset fast data/sample1.mp4

# OR copy existing video
cp data/some_video.mp4 data/sample1.mp4

# Restart
docker compose restart pipeline
```

### Issue 3: Dashboard not accessible

**Symptom:**
```
curl: (7) Failed to connect to localhost port 3000
```

**Fix:**
```bash
# Check if dashboard container is running
docker compose ps dashboard

# Check dashboard logs
docker compose logs dashboard

# If failed to build, check Node.js version
node --version  # Should be >= 22

# Rebuild dashboard
docker compose build dashboard
docker compose up -d dashboard
```

### Issue 4: LocalStack not responding

**Fix:**
```bash
# Restart LocalStack
docker compose restart localstack

# Check LocalStack logs
docker compose logs localstack

# Verify LocalStack is healthy
curl http://localhost:4566/_localstack/health
```

### Issue 5: Port 3000 already in use

**Fix:**
```bash
# Check what's using port 3000
sudo lsof -i :3000

# Kill the process or change the port in docker-compose.yml:
# ports:
#   - "3001:3000"  # Use 3001 instead

# Then access at http://localhost:3001
```

---

## Stopping and Cleaning Up

### Stop services (keeps data)
```bash
make local-down
# OR
docker compose down
```

### Stop and remove all data (complete clean)
```bash
docker compose down -v
# The -v flag removes volumes (LocalStack data)
```

### View running containers
```bash
docker compose ps
```

### Remove old images (free disk space)
```bash
docker system prune -a
```

---

## Expected Performance (Local)

On a typical laptop (4-8 cores):
- **FPS:** 15-30 fps (depends on CPU)
- **Latency P50:** 30-60ms
- **Latency P99:** 80-150ms
- **Detections:** 0-15 per frame (depends on video content)
- **Memory:** ~500MB per container
- **CPU:** 50-100% of allocated cores

On AWS Graviton4 (c8g.xlarge):
- **FPS:** 60-120 fps (with COOL optimizations)
- **Latency P50:** 8-15ms
- **Latency P99:** 20-40ms

---

## Quick Start Summary

```bash
# 1. Navigate to project
cd /home/augustineonuora/Dapps-Empty/2026/Oct2026/gravisonde

# 2. Ensure video exists
ls -lh data/sample1.mp4

# 3. Download YOLO model if missing
wget -O data/yolo11n.onnx \
  "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.onnx"

# 4. Start stack
make local-up

# 5. Open browser
xdg-open http://localhost:3000

# 6. Watch logs
docker compose logs -f pipeline

# 7. Stop when done
make local-down
```

---

## Next Steps

Once local is working:
1. ✅ View metrics in dashboard at http://localhost:3000
2. 📊 Download CSV benchmark data
3. 📸 Take screenshots for demo
4. 🎥 Record screen capture showing live metrics
5. 📝 Document findings in technical report

For AWS deployment (when SSH is fixed):
- See `FIX_REMOTE_DEPLOYMENT.md`
- See `DEPLOYMENT.md`
- See `docs/reproduction-guide.md`
