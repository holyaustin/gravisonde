# Quick Start Guide: Academic Data Collection

**Date:** 2026-11-02  
**Status:** Pipeline running, metrics flowing, ready for data collection

---

## Current Status ✓

- ✅ Pipeline is running and processing video
- ✅ Metrics are being collected in LocalStack
- ✅ Dashboard shows live metrics at http://localhost:3000
- ✅ CSV export via command line is working

---

## Immediate Actions: Get Your First Dataset

### Step 1: Export Current Metrics (Right Now)

```bash
cd /home/augustineonuora/Dapps-Empty/2026/Oct2026/gravisonde

# Make export script executable
chmod +x export-metrics-csv.sh

# Export metrics collected so far
./export-metrics-csv.sh results/baseline_test_$(date +%Y%m%d_%H%M%S).csv
```

**Expected output:**
```
✓ Success! Exported 1234 frames to: results/baseline_test_20261102_230630.csv

First 5 rows:
frameId  timestamp        latencyMs  inferenceMs  detections  instanceId       opencvVersion  arch      pipeline
0        1730498400123    45.2       42.1         3           gravisonde-demo  5.0.0.93       graviton  cool
1        1730498400156    43.8       41.5         3           gravisonde-demo  5.0.0.93       graviton  cool
...
```

### Step 2: Analyze Your First Dataset

```bash
# View summary statistics
python3 << 'EOF'
import pandas as pd
import sys

# Read CSV
df = pd.read_csv('results/baseline_test_*.csv')  # Use actual filename

print("=== Benchmark Summary ===\n")
print(f"Total frames: {len(df)}")
print(f"Duration: {(df['timestamp'].max() - df['timestamp'].min()) / 1000:.2f} seconds")
print(f"\nFPS: {len(df) / ((df['timestamp'].max() - df['timestamp'].min()) / 1000):.2f}")
print(f"\nLatency Statistics (ms):")
print(df['latencyMs'].describe())
print(f"\nDetections per frame:")
print(df['detections'].describe())
EOF
```

---

## For Your Academic Papers: Video Strategy

### Quick Answer to Your Question

**Do you need one video or different videos?**

➡️ **You need DIFFERENT videos for different papers:**

| Paper | Videos Needed | Strategy | Why Different? |
|-------|---------------|----------|----------------|
| **Paper 1** (ARM vs x86) | 3 videos, **SAME across hardware** | Static, Dynamic, Dense scenes | Isolate hardware differences |
| **Paper 2** (Cost-efficiency) | 3 videos, **DIFFERENT workloads** | Detection-heavy, Feature-heavy, Balanced | Show workload sensitivity |
| **Paper 3** (ALIKED vs ORB) | 4 videos, **DIFFERENT features** | High-texture, Low-texture, Lighting, Blur | Test detector robustness |

**Total: 8-10 unique videos needed**

---

## Practical Steps for Each Paper

### Paper 1: Architecture Comparison (ARM vs x86)

**Goal:** Prove Graviton4 is faster/cheaper than x86

**Videos needed:** Use SAME 3 videos on both architectures

```bash
# 1. Find or create 3 test videos
mkdir -p data/videos/paper1

# Option A: Generate synthetic videos (quick)
ffmpeg -f lavfi -i testsrc=duration=300:size=640x480:rate=30 \
  -vf "drawtext=text='Static Scene':fontsize=24:x=10:y=10" \
  data/videos/paper1/static_scene.mp4

# Option B: Use existing videos
cp data/sample1.mp4 data/videos/paper1/baseline.mp4

# 2. Run benchmark with current setup (local = x86-like)
./export-metrics-csv.sh results/paper1_local_baseline.csv

# 3. Later: Deploy to AWS Graviton4 and run same videos
# (once SSH is fixed)
```

### Paper 2: Cost-Efficiency Optimization

**Goal:** Find best instance type for cost-per-frame

**Videos needed:** DIFFERENT workloads to show sensitivity

```bash
mkdir -p data/videos/paper2

# Video 1: Detection-heavy (many objects, few features)
# Use: Traffic scene, crowded street
# Synthetic example:
ffmpeg -f lavfi -i testsrc=duration=300:size=640x480:rate=30 \
  -vf "drawbox=x=50:y=50:w=80:h=80:color=red@0.5:t=fill,
       drawbox=x=200:y=100:w=80:h=80:color=blue@0.5:t=fill,
       drawbox=x=400:y=200:w=80:h=80:color=green@0.5:t=fill" \
  data/videos/paper2/detection_heavy.mp4

# Video 2: Feature-heavy (few objects, complex textures)
# Use: Building facade, text-rich scene
wget https://sample-videos.com/video123/mp4/480/big_buck_bunny_480p_1mb.mp4 \
  -O data/videos/paper2/feature_heavy.mp4

# Video 3: Balanced
cp data/sample1.mp4 data/videos/paper2/balanced.mp4
```

### Paper 3: Feature Detector Comparison

**Goal:** Show ALIKED is better than ORB for quality features

**Videos needed:** DIFFERENT feature-richness levels

```bash
mkdir -p data/videos/paper3

# Video 1: High texture (ALIKED should win)
# Use: Urban scene with buildings, text, signs

# Video 2: Low texture (ORB sufficient)
# Use: Sky, water, uniform surfaces

# Video 3: Lighting changes
# Use: Indoor/outdoor transition

# Video 4: Motion blur
# Use: Fast camera movement
```

---

## Immediate Next Steps (Today)

### 1. Keep Current Pipeline Running
```bash
# Check it's still running
docker compose ps

# Watch metrics flow
docker compose logs -f pipeline | grep "frame_id"
```

### 2. Export Baseline Data Every 5 Minutes
```bash
# Run this in a loop
while true; do
  ./export-metrics-csv.sh "results/baseline_$(date +%H%M%S).csv"
  echo "Waiting 5 minutes..."
  sleep 300
done
```

### 3. Start Collecting Different Video Samples

**Find or create your 8-10 videos:**

#### Option A: Use Public Datasets
```bash
# KITTI dataset (autonomous driving)
wget http://kitti.is.tue.mpg.de/kitti/raw_data/2011_09_26_drive_0001/...

# MOT17 (pedestrian tracking)
wget https://motchallenge.net/data/MOT17/...

# COCO validation set videos
# Download from: https://cocodataset.org/#download
```

#### Option B: YouTube Creative Commons Videos
```bash
# Use youtube-dl to download CC videos
pip install yt-dlp

yt-dlp -f "best[height<=480]" \
  --output "data/videos/%(title)s.%(ext)s" \
  "https://www.youtube.com/watch?v=VIDEO_ID"
```

#### Option C: Generate Synthetic Test Videos
```bash
# See video generation script below
./scripts/generate_test_videos.sh
```

---

## Video Generation Helper Script

```bash
#!/bin/bash
# generate_test_videos.sh
# Creates synthetic test videos for papers

mkdir -p data/videos/{paper1,paper2,paper3}

echo "Generating test videos for academic papers..."

# Paper 1: Static scene
ffmpeg -f lavfi -i testsrc=duration=300:size=640x480:rate=30 \
  -vf "drawtext=text='Static Scene':fontsize=24:x=10:y=10:fontcolor=white" \
  data/videos/paper1/static_scene.mp4 -y

# Paper 1: Dynamic scene (moving objects)
ffmpeg -f lavfi -i testsrc=duration=300:size=640x480:rate=30 \
  -vf "drawbox=x='50+200*sin(t)':y=100:w=80:h=80:color=red@0.5:t=fill" \
  data/videos/paper1/dynamic_scene.mp4 -y

# Paper 2: Detection-heavy (many boxes)
ffmpeg -f lavfi -i testsrc=duration=300:size=640x480:rate=30 \
  -vf "drawbox=x=50:y=50:w=80:h=80:color=red@0.5:t=fill,
       drawbox=x=200:y=100:w=80:h=80:color=blue@0.5:t=fill,
       drawbox=x=400:y=200:w=80:h=80:color=green@0.5:t=fill,
       drawbox=x=300:y=300:w=80:h=80:color=yellow@0.5:t=fill" \
  data/videos/paper2/detection_heavy.mp4 -y

echo "✓ Test videos generated in data/videos/"
```

---

## Data Organization for Papers

```
gravisonde/
├── data/
│   └── videos/
│       ├── paper1/           # Same videos, test on different hardware
│       │   ├── static_scene.mp4
│       │   ├── dynamic_scene.mp4
│       │   └── dense_objects.mp4
│       ├── paper2/           # Different workloads
│       │   ├── detection_heavy.mp4
│       │   ├── feature_heavy.mp4
│       │   └── balanced.mp4
│       └── paper3/           # Different feature characteristics
│           ├── high_texture.mp4
│           ├── low_texture.mp4
│           ├── lighting_change.mp4
│           └── motion_blur.mp4
└── results/
    ├── paper1/
    │   ├── local_x86/        # Your laptop (current)
    │   └── aws_graviton4/    # EC2 results (future)
    ├── paper2/
    └── paper3/
```

---

## Summary: What You Need to Do

### Today (Local Testing)
1. ✅ Keep pipeline running
2. ✅ Export baseline metrics: `./export-metrics-csv.sh results/baseline.csv`
3. ✅ Test with current video to validate data collection
4. 📹 Find or create 8-10 test videos
5. 📊 Run each video through local pipeline
6. 💾 Save all CSV files organized by paper

### This Week (Prepare for AWS)
1. 🔧 Fix EC2 SSH access (security group port 22)
2. 🚀 Deploy pipeline to Graviton4 instance
3. 📹 Run SAME videos on both local and Graviton4
4. 📊 Collect comparison data

### Paper-Specific Data Collection
| Paper | Video Count | Same/Different | Priority |
|-------|-------------|----------------|----------|
| Paper 1 | 3 videos | SAME on both hardware | HIGH |
| Paper 2 | 3 videos | DIFFERENT workloads | MEDIUM |
| Paper 3 | 4 videos | DIFFERENT features | MEDIUM |

---

## Quick Commands Reference

```bash
# Export metrics NOW
./export-metrics-csv.sh results/test_$(date +%s).csv

# Check pipeline status
docker compose ps
docker compose logs pipeline | tail -20

# Restart pipeline with new video
docker compose down
# Edit docker-compose.yml to change video path
docker compose up -d

# View live metrics
curl http://localhost:3000/api/metrics

# Stop everything
docker compose down
```

---

## Next: Fix Dashboard CSV Download

See `ACADEMIC_DATA_COLLECTION_PLAN.md` for the dashboard fix details. For now, use the command-line export script.

The dashboard download button issue is a frontend problem - the backend (LocalStack) has all the data and the CLI export works perfectly.
