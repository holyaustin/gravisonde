# Academic Paper Data Collection Plan for Gravisonde
**Date:** 2026-11-02  
**Purpose:** Systematic data collection strategy for 3 CV5 academic papers

---

## Paper 1: Architecture-Aware Computer Vision (ARM vs x86)

### Research Question
Does Graviton4 (ARM) outperform x86 (Intel Ice Lake) for OpenCV 5 YOLO11n inference in FPS, latency, and cost-efficiency?

### Required Data

#### Hardware Configurations
| Configuration | Instance Type | vCPUs | RAM | Cost/hr | Architecture |
|---------------|---------------|-------|-----|---------|--------------|
| **Config A** | c8g.xlarge | 4 | 8GB | $0.136 | ARM Graviton4 |
| **Config B** | c7i.xlarge | 4 | 8GB | $0.170 | x86 Intel Ice Lake |

#### Pipeline Modes (Both Architectures)
1. **COOL** (optimized OpenCV 5 with ARM KleidiCV)
2. **Stock** (standard OpenCV 5 build)

#### Video Datasets Needed

**Use the SAME videos across all configurations for fair comparison.**

```bash
# Dataset 1: Static Scene (Low Motion)
# Purpose: Baseline detection performance, minimal optical flow
# Characteristics: 30 fps, 640x480, mostly stationary objects
videos/paper1_static_scene.mp4         # 5 minutes

# Dataset 2: Dynamic Scene (High Motion)  
# Purpose: Test under frame-to-frame change stress
# Characteristics: 30 fps, 640x480, moving vehicles/people
videos/paper1_dynamic_scene.mp4        # 5 minutes

# Dataset 3: Dense Objects Scene
# Purpose: Max detection load (many objects per frame)
# Characteristics: 30 fps, 640x480, crowded urban scene
videos/paper1_dense_objects.mp4        # 5 minutes
```

#### Experimental Matrix (24 runs total)

```
For each video (3 videos):
  For each architecture (ARM, x86):
    For each pipeline (COOL, Stock):
      Run benchmark for 300 seconds (5 minutes)
      
Total: 3 videos × 2 architectures × 2 pipelines × 2 replicates = 24 runs
```

#### Metrics to Collect (per run)
- `avg_fps` - Average frames per second
- `p50_latency_ms` - Median latency
- `p95_latency_ms` - 95th percentile latency
- `p99_latency_ms` - 99th percentile latency (tail latency)
- `avg_detections_per_frame` - Average objects detected
- `fps_per_dollar` - Cost efficiency metric
- `total_frames` - Total frames processed
- `frame_drops` - Number of dropped frames (if any)

#### Data Collection Commands

```bash
# ARM Graviton4 + COOL
docker run --name bench_arm_cool \
  -e PIPELINE_MODE=cool \
  -e ARCH=graviton \
  -v /data/videos/paper1_static_scene.mp4:/data/sample.mp4:ro \
  -v /data/yolo11n.onnx:/app/yolo11n.onnx:ro \
  gravisonde-pipeline --duration 300

# Export CSV
docker cp bench_arm_cool:/tmp/benchmark_results.csv \
  ./results/paper1_arm_cool_static_run1.csv

# Repeat for: arm_stock, x86_cool, x86_stock
```

---

## Paper 2: Cost-Aware Edge Inference (FPS-per-Dollar)

### Research Question
What is the optimal instance type for video analytics when optimizing for cost-efficiency (FPS/$) rather than raw speed?

### Required Data

#### Hardware Configurations (Wider Range)
| Instance | vCPUs | RAM | Cost/hr | Architecture | Use Case |
|----------|-------|-----|---------|--------------|----------|
| c8g.medium | 1 | 2GB | $0.034 | ARM | Edge/IoT |
| c8g.large | 2 | 4GB | $0.068 | ARM | Small deployment |
| c8g.xlarge | 4 | 8GB | $0.136 | ARM | Standard |
| c8g.2xlarge | 8 | 16GB | $0.272 | ARM | High-throughput |
| c7i.xlarge | 4 | 8GB | $0.170 | x86 | Comparison baseline |

#### Pipeline Workload Types

**Important:** Use DIFFERENT videos to show workload sensitivity.

```bash
# Workload 1: Detection-Heavy (DNN-dominant)
# Many objects, frequent detections, minimal feature tracking
videos/paper2_detection_heavy.mp4      # Dense urban traffic, 5 min

# Workload 2: Feature-Heavy (ALIKED+LightGlue dominant)
# Few objects, extensive feature matching between frames
videos/paper2_feature_heavy.mp4        # Sparse scene with texture, 5 min

# Workload 3: Balanced
# Mix of detection and feature extraction
videos/paper2_balanced.mp4             # Suburban scene, 5 min
```

#### Experimental Matrix (30 runs)

```
For each instance type (5 types):
  For each workload type (3 workloads):
    Run benchmark for 300 seconds
    Calculate FPS, FPS/$, latency
    
Total: 5 instances × 3 workloads × 2 replicates = 30 runs
```

#### Key Metrics
- `fps` - Raw throughput
- `fps_per_dollar` - **Primary metric** (normalized efficiency)
- `inference_ms` - Breakdown: detection time vs feature time
- `cost_per_1000_frames` - Derived metric for cost modeling
- `power_efficiency_estimate` - If available from EC2 API

#### Analysis Focus
- Plot FPS-per-dollar vs raw FPS (show non-linear relationship)
- Identify "sweet spot" instance type for each workload
- Show that highest FPS ≠ best cost-efficiency

---

## Paper 3: Learned vs Classical Features (ALIKED vs ORB)

### Research Question
Do learned feature detectors (ALIKED+LightGlue) justify their computational overhead vs classical methods (ORB+BFMatcher) under real-time constraints?

### Required Data

#### Feature Detector Configurations
| Config | Detector | Matcher | Model Size | Expected Latency |
|--------|----------|---------|------------|------------------|
| **Classical** | ORB | BFMatcher | 0 MB (built-in) | Low |
| **Learned** | ALIKED | LightGlue | ~50 MB | High |
| **Fallback** | ORB (ALIKED unavailable) | BFMatcher | 0 MB | Low |

#### Video Datasets (Feature Quality Matters)

**Use videos with varying feature-richness:**

```bash
# Scene 1: High-Texture (many features)
# Purpose: Show ALIKED advantage in feature-rich scenes
videos/paper3_high_texture.mp4         # Urban, buildings, text, 5 min

# Scene 2: Low-Texture (few features)
# Purpose: Show when ORB is sufficient
videos/paper3_low_texture.mp4          # Open field, sky, water, 5 min

# Scene 3: Lighting Changes
# Purpose: Test robustness to illumination variation
videos/paper3_lighting_change.mp4      # Indoor to outdoor, 5 min

# Scene 4: Motion Blur
# Purpose: Test under challenging conditions
videos/paper3_motion_blur.mp4          # Fast camera pan, 5 min
```

#### Experimental Matrix (24 runs)

```
For each video (4 videos):
  For each detector config (Classical, Learned, Fallback):
    Run benchmark for 300 seconds
    Measure: feature count, match quality, latency
    
Total: 4 videos × 3 configs × 2 replicates = 24 runs
```

#### Metrics to Collect
- `keypoints_detected_per_frame` - Feature count
- `matches_per_frame` - Successfully matched features
- `inference_ms` - **Breakdown:** detection time + feature time
- `feature_extraction_ms` - Isolated feature extraction latency
- `matching_ms` - Isolated matching latency
- `match_inlier_ratio` - Quality metric (if available)

#### Data Collection Setup

```bash
# Classical ORB
docker run --name bench_orb \
  -e FEATURE_DETECTOR=orb \
  -e USE_LIGHTGLUE_MATCHER=false \
  -v /data/videos/paper3_high_texture.mp4:/data/sample.mp4:ro \
  gravisonde-pipeline --duration 300

# Learned ALIKED+LightGlue
docker run --name bench_aliked \
  -e FEATURE_DETECTOR=aliked \
  -e USE_LIGHTGLUE_MATCHER=true \
  -e ALIKED_MODEL_PATH=/models/aliked.onnx \
  -e LIGHTGLUE_MODEL_PATH=/models/lightglue.onnx \
  -v /data/videos/paper3_high_texture.mp4:/data/sample.mp4:ro \
  gravisonde-pipeline --duration 300
```

---

## Overall Data Collection Strategy

### Video Requirements Summary

| Paper | Unique Videos | Video Characteristics | Total Duration |
|-------|---------------|----------------------|----------------|
| Paper 1 | 3 | Same videos, different hardware | 15 min |
| Paper 2 | 3 | Different workload types | 15 min |
| Paper 3 | 4 | Feature-richness variation | 20 min |
| **Total Unique** | **8-10 videos** | Mix of scenes | **45-50 min** |

### Recommended Video Sources

```bash
# Option 1: Use existing public datasets
# - KITTI (autonomous driving) - dense objects
# - MOT17 (pedestrian tracking) - high motion
# - YouTube-8M (various scenes) - diverse content

# Option 2: Generate synthetic videos with known properties
ffmpeg -f lavfi -i testsrc=duration=300:size=640x480:rate=30 \
  -vf "drawbox=x=50:y=50:w=100:h=100:color=red@0.5:t=fill" \
  videos/synthetic_static.mp4

# Option 3: Record custom videos with specific characteristics
# Use phone/camera to record:
# - Static: tripod shot of street
# - Dynamic: handheld walking through crowd
# - Dense: traffic intersection footage
```

### Data Storage Structure

```
gravisonde/
├── data/
│   └── videos/
│       ├── paper1_static_scene.mp4
│       ├── paper1_dynamic_scene.mp4
│       ├── paper1_dense_objects.mp4
│       ├── paper2_detection_heavy.mp4
│       ├── paper2_feature_heavy.mp4
│       ├── paper2_balanced.mp4
│       ├── paper3_high_texture.mp4
│       ├── paper3_low_texture.mp4
│       ├── paper3_lighting_change.mp4
│       └── paper3_motion_blur.mp4
├── results/
│   ├── paper1/
│   │   ├── raw_csv/          # Raw per-frame metrics
│   │   ├── aggregated/       # Summary statistics per run
│   │   └── analysis/         # Statistical analysis outputs
│   ├── paper2/
│   └── paper3/
└── analysis/
    ├── paper1_analysis.ipynb
    ├── paper2_analysis.ipynb
    └── paper3_analysis.ipynb
```

---

## Data Collection Automation

### Create Batch Runner Script

```bash
#!/bin/bash
# run_paper_benchmarks.sh

PAPERS=("paper1" "paper2" "paper3")
RESULTS_DIR="./results"

for paper in "${PAPERS[@]}"; do
  mkdir -p "$RESULTS_DIR/$paper/raw_csv"
  
  # Load paper-specific video list
  source "./configs/${paper}_videos.txt"
  
  for video in "${VIDEOS[@]}"; do
    for config in "${CONFIGS[@]}"; do
      echo "Running $paper - $video - $config"
      
      # Run benchmark
      docker run --name "bench_${paper}_${video}_${config}" \
        -e PIPELINE_MODE="$config" \
        -v "./data/videos/$video:/data/sample.mp4:ro" \
        -v "./data/yolo11n.onnx:/app/yolo11n.onnx:ro" \
        gravisonde-pipeline --duration 300
      
      # Extract CSV
      docker cp "bench_${paper}_${video}_${config}:/tmp/benchmark.csv" \
        "$RESULTS_DIR/$paper/raw_csv/${paper}_${video}_${config}.csv"
      
      # Cleanup
      docker rm -f "bench_${paper}_${video}_${config}"
      
      sleep 10  # Cool-down between runs
    done
  done
done
```

---

## Fixing the Dashboard CSV Download Issue

The dashboard CSV download button not working is likely a CORS or endpoint issue. Let me check:

```bash
# Check if metrics API is accessible
curl http://localhost:3000/api/metrics

# Check if download endpoint exists
curl http://localhost:3000/api/benchmark/download
```

**Fix needed:** Update dashboard to properly generate and serve CSV from accumulated metrics.

---

## Alternative: Use Command-Line CSV Export

Since CMD export works, use this for now:

```bash
# Export metrics from LocalStack CloudWatch Logs
aws logs filter-log-events \
  --log-group-name /aws/gravisonde/pipeline \
  --start-time $(date -d '10 minutes ago' +%s)000 \
  --endpoint-url http://localhost:4566 \
  --region eu-north-1 \
  --no-sign-request \
  --output json | \
  jq -r '.events[].message | fromjson | 
    [.frameId, .ts, .latencyMs, .inferenceMs, .detections, .instanceId, .opencvVersion, .arch, .pipeline] | 
    @csv' > benchmark_$(date +%Y%m%d_%H%M%S).csv
```

---

## Summary

### For Paper 1 (Architecture Comparison)
- **Videos:** 3 (same videos across all configs)
- **Use same video content** to isolate hardware differences
- **Focus:** ARM vs x86, COOL vs Stock

### For Paper 2 (Cost-Efficiency)
- **Videos:** 3 (different workload types)
- **Use different video characteristics** to show workload sensitivity
- **Focus:** FPS-per-dollar across instance types

### For Paper 3 (Feature Detectors)
- **Videos:** 4 (varying feature-richness)
- **Use different scene properties** to test detector robustness
- **Focus:** ALIKED vs ORB performance/accuracy tradeoff

### Key Differences
| Paper | Video Strategy | Why Different Videos? |
|-------|----------------|----------------------|
| Paper 1 | Same videos | Isolate hardware variable |
| Paper 2 | Different workloads | Show workload sensitivity |
| Paper 3 | Different scenes | Test feature detector robustness |

**Total: 8-10 unique videos, ~50 minutes total duration**
