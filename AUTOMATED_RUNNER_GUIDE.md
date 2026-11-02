# Automated Benchmark Runner - Complete Guide

**Created:** 2026-11-02  
**Purpose:** Fully automated academic data collection for 3 CV papers

---

## What This Does

The automated benchmark runner:
1. ✅ **Generates 10 test videos** automatically (Paper 1: 3, Paper 2: 3, Paper 3: 4)
2. ✅ **Tests on both x86 AND ARM** using Docker's multi-platform capabilities
3. ✅ **Runs each test for 5 minutes** automatically
4. ✅ **Exports metrics to CSV** after each test
5. ✅ **Shows live progress** with current status display
6. ✅ **Generates summary report** with all results

**Total Runtime:** ~100 minutes (20 tests × 5 minutes each)  
**No manual intervention needed** - set it and forget it!

---

## Quick Start

### One Command to Run Everything

```bash
cd /home/augustineonuora/Dapps-Empty/2026/Oct2026/gravisonde

# Run the complete benchmark suite
./automated-benchmark-runner.sh
```

That's it! The script will:
- Generate all videos
- Run all tests on x86 and ARM
- Export all results
- Create summary report

### Monitor Progress

While running, check status in another terminal:

```bash
# Watch live status
watch -n 5 cat benchmark_status.txt

# View progress log
tail -f benchmark_progress.log

# See what's happening now
docker ps
```

---

## What Gets Created

### Directory Structure After Running

```
gravisonde/
├── data/
│   └── videos/
│       ├── paper1/
│       │   ├── static_scene.mp4
│       │   ├── dynamic_scene.mp4
│       │   └── dense_objects.mp4
│       ├── paper2/
│       │   ├── detection_heavy.mp4
│       │   ├── feature_heavy.mp4
│       │   └── balanced.mp4
│       └── paper3/
│           ├── high_texture.mp4
│           ├── low_texture.mp4
│           ├── lighting_change.mp4
│           └── motion_blur.mp4
├── results/
│   ├── paper1/
│   │   ├── x86/
│   │   │   ├── static_scene_20261102_070000.csv
│   │   │   ├── dynamic_scene_20261102_070530.csv
│   │   │   └── dense_objects_20261102_071100.csv
│   │   └── arm/
│   │       ├── static_scene_20261102_071630.csv
│   │       ├── dynamic_scene_20261102_072200.csv
│   │       └── dense_objects_20261102_072730.csv
│   ├── paper2/
│   │   ├── x86/
│   │   └── arm/
│   ├── paper3/
│   │   ├── x86/
│   │   └── arm/
│   ├── benchmark_summary_20261102_090000.txt
│   └── analysis_summary.json
├── logs/
│   ├── bench_paper1_static_scene_x86.log
│   ├── bench_paper1_static_scene_arm.log
│   └── ... (one log per test)
├── benchmark_status.txt          # Current status
└── benchmark_progress.log        # Full progress log
```

---

## Understanding x86 vs ARM Testing Locally

### How It Works

Your laptop is **x86 (Intel/AMD)**. The script tests **both architectures** using:

1. **x86 (Native)** - Runs directly on your CPU (fast)
2. **ARM (Emulated)** - Uses QEMU emulation (slower but validates code)

### What This Means

| Platform | Speed | Purpose |
|----------|-------|---------|
| **x86** | Normal | Baseline performance for Intel/AMD CPUs |
| **ARM** | ~2-5x slower | Validates ARM compatibility, simulates Graviton |

⚠️ **Note:** ARM results from QEMU emulation are **NOT** accurate for performance comparison. They validate that your code works on ARM, but for real ARM performance numbers, you need actual Graviton4 hardware (AWS EC2).

### For Accurate Paper 1 Results

**Option A:** Use emulated results as placeholder
- Shows your code works on both architectures
- Use relative differences (x86 fast, ARM slower due to emulation)
- Mention "emulated" in paper methodology

**Option B:** Get real ARM hardware (Recommended for Paper 1)
- Fix EC2 SSH access (security group issue)
- Deploy to AWS c8g.xlarge (Graviton4)
- Re-run benchmarks on real ARM hardware
- Use those results for Paper 1

---

## Test Matrix

### Paper 1: Architecture Comparison
| Video | x86 Test | ARM Test | Purpose |
|-------|----------|----------|---------|
| Static Scene | ✓ | ✓ | Baseline, low motion |
| Dynamic Scene | ✓ | ✓ | High motion, tracking |
| Dense Objects | ✓ | ✓ | Many detections |

**Expected Runtime:** 6 tests × 5 min = 30 minutes

### Paper 2: Cost-Efficiency  
| Video | x86 Test | ARM Test | Workload Type |
|-------|----------|----------|---------------|
| Detection Heavy | ✓ | ✓ | DNN-dominant |
| Feature Heavy | ✓ | ✓ | Feature extraction |
| Balanced | ✓ | ✓ | Mixed workload |

**Expected Runtime:** 6 tests × 5 min = 30 minutes

### Paper 3: Feature Detectors
| Video | x86 Test | ARM Test | Scene Type |
|-------|----------|----------|------------|
| High Texture | ✓ | ✓ | Complex patterns |
| Low Texture | ✓ | ✓ | Uniform surfaces |
| Lighting Change | ✓ | ✓ | Illumination variation |
| Motion Blur | ✓ | ✓ | Fast movement |

**Expected Runtime:** 8 tests × 5 min = 40 minutes

**Total:** 20 tests × 5 minutes = **100 minutes (~1.7 hours)**

---

## Analyzing Results

### After Benchmarks Complete

```bash
# Run analysis script
python3 analyze_results.py results/

# This generates:
# - Console output with statistics
# - LaTeX tables for papers
# - JSON summary file
```

### Expected Analysis Output

```
===========================================================
Gravisonde Benchmark Analysis
Results directory: results/
Analysis time: 2026-11-02 09:00:00
===========================================================

Loading CSV files...
✓ Loaded: paper1/x86/static_scene (9000 frames)
✓ Loaded: paper1/arm/static_scene (2700 frames)
...

======================================================================
Paper 1: Architecture-Aware Computer Vision
ARM Graviton vs x86 Comparison
======================================================================

STATIC_SCENE:
--------------------------------------------------
  x86  - FPS:  30.00 | P99:  45.20ms | Frames: 9000
  ARM  - FPS:   9.00 | P99: 150.80ms | Frames: 2700
  Speedup: 0.30x | P99 Latency Improvement: -233.6%
  (Note: ARM emulated, not representative of real Graviton4)

OVERALL SUMMARY
Average ARM Speedup: 0.30x (emulated - actual Graviton4 is ~1.5-2x)
Average P99 Latency Improvement: -200% (emulated overhead)
```

---

## Troubleshooting

### Script Fails to Start

```bash
# Check prerequisites
./automated-benchmark-runner.sh

# If Docker not running:
sudo systemctl start docker

# If ffmpeg missing:
sudo apt-get install ffmpeg
```

### Container Fails During Test

```bash
# Check logs
cat logs/bench_paper1_static_scene_x86.log

# Common issues:
# - YOLO model not found: Download with wget (script handles this)
# - Video not found: Check data/videos/ directory
# - Out of memory: Reduce video resolution or close other apps
```

### ARM Tests Very Slow

This is **expected**! ARM emulation via QEMU is 2-5x slower than native x86.

**Solutions:**
- Wait it out (accurate for code validation)
- Skip ARM tests by editing script (remove "arm" from PLATFORMS array)
- Use real Graviton4 hardware for accurate performance

### No CSV Files Generated

```bash
# Check if LocalStack is running
docker ps | grep localstack

# Restart LocalStack
docker compose up -d localstack

# Try manual export
./export-metrics-csv.sh results/manual_test.csv
```

---

## Customization

### Change Test Duration

Edit `automated-benchmark-runner.sh`:

```bash
# Line 9: Change from 300s (5 min) to 60s (1 min) for quick tests
BENCHMARK_DURATION=60
```

### Skip ARM Tests

Edit `automated-benchmark-runner.sh`:

```bash
# Line 248: Remove "arm" from platforms
PLATFORMS=("x86")  # Only test x86
```

### Run Only One Paper

```bash
# Modify the PAPERS array (around line 236)
declare -A PAPERS
PAPERS=(
    ["paper1"]="static_scene dynamic_scene dense_objects"
    # Comment out paper2 and paper3:
    # ["paper2"]="detection_heavy feature_heavy balanced"
    # ["paper3"]="high_texture low_texture lighting_change motion_blur"
)
```

---

## Next Steps

### After Automated Run Completes

1. **Review results:**
   ```bash
   cat results/benchmark_summary_*.txt
   ```

2. **Analyze data:**
   ```bash
   python3 analyze_results.py results/
   ```

3. **Create plots** (use Python/R/MATLAB):
   ```python
   import pandas as pd
   import matplotlib.pyplot as plt
   
   # Load results
   df_x86 = pd.read_csv('results/paper1/x86/static_scene_*.csv')
   df_arm = pd.read_csv('results/paper1/arm/static_scene_*.csv')
   
   # Plot FPS comparison
   plt.bar(['x86', 'ARM'], [len(df_x86)/300, len(df_arm)/300])
   plt.ylabel('FPS')
   plt.title('x86 vs ARM Performance')
   plt.savefig('paper1_fps_comparison.png')
   ```

4. **Write papers** using the data and plots

5. **(Optional) Re-run on real Graviton4:**
   - Fix EC2 SSH (security group port 22)
   - Deploy to AWS c8g.xlarge
   - Run same tests on real ARM hardware
   - Replace emulated ARM data with real results

---

## Summary

### What You Get

✅ **10 test videos** automatically generated  
✅ **20 benchmark runs** (10 videos × 2 platforms)  
✅ **20 CSV files** with per-frame metrics  
✅ **Complete logs** for debugging  
✅ **Summary report** with key statistics  
✅ **Analysis script** for generating tables  

### Time Investment

- **Setup:** 5 minutes (run script)
- **Execution:** 100 minutes (automated)
- **Analysis:** 10 minutes (review results)
- **Total:** ~2 hours hands-off time

### Data Quality

- **x86 results:** ✓ Accurate (native execution)
- **ARM results:** ⚠️ Emulated (validates code, not performance)
- **For Paper 1:** Use real Graviton4 hardware for publication
- **For Paper 2 & 3:** x86 results alone are sufficient

---

## Commands Reference

```bash
# Run everything
./automated-benchmark-runner.sh

# Monitor progress
watch -n 5 cat benchmark_status.txt
tail -f benchmark_progress.log

# Analyze results
python3 analyze_results.py results/

# View summary
cat results/benchmark_summary_*.txt

# Manual CSV export
./export-metrics-csv.sh results/manual.csv

# Check running containers
docker ps
docker logs <container_name>

# Stop everything
docker compose down
```

---

## Getting Real ARM Performance (For Paper 1)

Once EC2 SSH is fixed:

```bash
# 1. SSH to Graviton4 instance
ssh -i ~/.ssh/gravisonde-aws-key1.pem ec2-user@<IP>

# 2. Clone repo on EC2
git clone <your-repo> && cd gravisonde

# 3. Run benchmarks on real ARM
./automated-benchmark-runner.sh

# 4. Download results
scp -i ~/.ssh/gravisonde-aws-key1.pem -r \
  ec2-user@<IP>:~/gravisonde/results ./results_graviton4/

# 5. Compare x86 (local) vs ARM (Graviton4)
python3 analyze_results.py results/         # Local x86
python3 analyze_results.py results_graviton4/  # Real ARM
```

---

**Ready to start? Just run:**

```bash
./automated-benchmark-runner.sh
```

The script will handle everything and report progress. Check back in ~2 hours for complete results!
