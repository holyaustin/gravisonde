# 🚀 QUICK START - One Command Setup

**Date:** 2026-11-02  
**Time:** ~2 hours automated runtime  
**Output:** Complete academic dataset for 3 papers

---

## ⚡ Run Everything (One Command)

```bash
cd ~/Dapps-Empty/2026/Oct2026/gravisonde
./automated-benchmark-runner.sh
```

**That's it!** The script will:
1. Generate 10 test videos (10 minutes)
2. Run 20 benchmarks (x86 + ARM emulated) (100 minutes)
3. Export all metrics to CSV
4. Create summary report

---

## 📊 What You'll Get

### Data for Each Paper

| Paper | Focus | Videos | Tests | Output Files |
|-------|-------|--------|-------|--------------|
| **Paper 1** | x86 vs ARM | 3 | 6 | 6 CSV files |
| **Paper 2** | Cost-efficiency | 3 | 6 | 6 CSV files |
| **Paper 3** | ALIKED vs ORB | 4 | 8 | 8 CSV files |
| **Total** | | **10** | **20** | **20 CSV files** |

### Results Location

```
results/
├── paper1/
│   ├── x86/
│   │   ├── static_scene_20261102_070000.csv       (9000+ frames)
│   │   ├── dynamic_scene_20261102_070530.csv
│   │   └── dense_objects_20261102_071100.csv
│   └── arm/
│       ├── static_scene_20261102_071630.csv       (3000+ frames, emulated)
│       └── ... (same videos on ARM)
├── paper2/... (same structure)
├── paper3/... (same structure)
└── benchmark_summary_20261102_090000.txt          (Final report)
```

---

## 👀 Monitor Progress

### Real-Time Status

```bash
# Terminal 1: Run the benchmark
./automated-benchmark-runner.sh

# Terminal 2: Watch status (updates every 5 seconds)
watch -n 5 cat benchmark_status.txt

# Terminal 3: Follow logs
tail -f benchmark_progress.log
```

### Expected Status Messages

```
Step 1/5: Checking prerequisites
Step 2/5: Generating test videos (10 videos, ~10 minutes)
Step 3/5: Building Docker images (x86 and ARM)
Step 4/5: Running benchmarks (20 tests × 5 min = ~100 minutes)
  Test 1/20: paper1/static_scene on x86
  Test 2/20: paper1/static_scene on arm
  Test 3/20: paper1/dynamic_scene on x86
  ...
Step 5/5: Generating summary report
COMPLETE: All benchmarks finished successfully
```

---

## 📈 Analyze Results

### After Completion (~2 hours)

```bash
# Analyze all data
python3 analyze_results.py results/

# View summary
cat results/benchmark_summary_*.txt

# Check specific paper results
ls -lh results/paper1/x86/
ls -lh results/paper1/arm/
```

### Expected Analysis Output

```
Paper 1: Architecture-Aware Computer Vision
============================================

STATIC_SCENE:
  x86  - FPS:  30.00 | P99:  45.20ms | Frames: 9000
  ARM  - FPS:   9.00 | P99: 150.80ms | Frames: 2700
  
OVERALL SUMMARY:
  Average x86 FPS: 30.00
  Average ARM FPS: 9.00 (emulated - real Graviton4 will be ~60 FPS)
  
Paper 2: Cost-Aware Edge Inference
===================================

DETECTION_HEAVY:
  x86  - FPS:  28.50 | FPS/$: 167.65 | Cost/1k: $0.0021
  ARM  - FPS:   8.70 | FPS/$:  63.97 | Cost/1k: $0.0054
  
Paper 3: Feature Detector Comparison
====================================

HIGH_TEXTURE:
  x86  - FPS:  25.30 | Inference: 39.50ms | Detections: 8.2/frame
  ARM  - FPS:   7.80 | Inference: 128.20ms | Detections: 8.1/frame
```

---

## ⚠️ Important Notes

### x86 vs ARM Performance

| Platform | What It Is | Performance | Use For |
|----------|-----------|-------------|---------|
| **x86** | Your laptop (native) | ✅ Accurate | Papers 2 & 3 |
| **ARM** | QEMU emulation | ⚠️ 3-5x slower than real ARM | Code validation only |
| **Graviton4** | Real ARM on AWS | ✅ Accurate | Paper 1 (need EC2) |

**For Paper 1 (x86 vs ARM comparison):** You need real Graviton4 data from AWS EC2, not emulated results.

**For Papers 2 & 3:** x86 data alone is sufficient.

---

## 🔧 Troubleshooting

### Script Won't Start

```bash
# Check Docker is running
sudo systemctl start docker
docker ps

# Install missing tools
sudo apt-get install ffmpeg jq

# Make scripts executable
chmod +x automated-benchmark-runner.sh
```

### Test Fails Mid-Run

```bash
# Check logs
cat logs/bench_paper1_static_scene_x86.log

# Restart from where it stopped (edit script to skip completed tests)
# Or just re-run - it will overwrite with new timestamps
./automated-benchmark-runner.sh
```

### Out of Disk Space

```bash
# Videos use ~100MB total
# CSV files use ~50MB total
# Docker images use ~2GB

# Free up space
docker system prune -a
rm -rf results/old_results/
```

### ARM Tests Too Slow

```bash
# Option 1: Skip ARM tests (only test x86)
# Edit automated-benchmark-runner.sh line 248:
PLATFORMS=("x86")  # Remove "arm"

# Option 2: Reduce test duration
# Edit automated-benchmark-runner.sh line 9:
BENCHMARK_DURATION=60  # 1 minute instead of 5
```

---

## 📝 What to Do With Results

### For Each Paper

**Paper 1 (Architecture Comparison):**
1. ⚠️ Note: ARM results are emulated (not real Graviton4)
2. Use x86 data as baseline
3. When EC2 SSH is fixed, re-run on real Graviton4
4. Compare real ARM vs x86 for publication

**Paper 2 (Cost-Efficiency):**
1. ✅ Use x86 results directly
2. Calculate FPS-per-dollar for different instance types
3. Plot efficiency curves
4. No real ARM needed (using cost estimates)

**Paper 3 (Feature Detectors):**
1. ✅ Use x86 results directly  
2. Compare detection quality across scenes
3. Analyze latency vs accuracy tradeoffs
4. No real ARM needed (algorithm comparison)

### Create Publication Figures

```python
import pandas as pd
import matplotlib.pyplot as plt

# Paper 1: FPS comparison
x86_fps = [30.0, 28.5, 27.3]  # Load from CSVs
arm_fps = [9.0, 8.7, 8.2]     # Emulated (replace with real Graviton4)
videos = ['Static', 'Dynamic', 'Dense']

plt.figure(figsize=(8, 6))
x = range(len(videos))
plt.bar([i-0.2 for i in x], x86_fps, 0.4, label='x86')
plt.bar([i+0.2 for i in x], arm_fps, 0.4, label='ARM (emulated)')
plt.xticks(x, videos)
plt.ylabel('FPS')
plt.title('Paper 1: Architecture Comparison')
plt.legend()
plt.savefig('paper1_figure1.png', dpi=300)
```

---

## ⏱️ Timeline

| Time | Activity | Status |
|------|----------|--------|
| 0:00 | Start script | 🏁 |
| 0:10 | Videos generated | ✓ |
| 0:15 | Docker images built | ✓ |
| 0:20 | First test running (paper1/static_scene/x86) | 🔄 |
| 0:25 | Second test running (paper1/static_scene/arm) | 🔄 |
| ... | Tests continue automatically | 🔄 |
| 1:50 | Last test running (paper3/motion_blur/arm) | 🔄 |
| 1:55 | Generating summary | 🔄 |
| 2:00 | **COMPLETE** | ✅ |

---

## 🎯 Success Checklist

After 2 hours, you should have:

- [x] 10 video files in `data/videos/`
- [x] 20 CSV files in `results/paper*/x86/` and `results/paper*/arm/`
- [x] 20 log files in `logs/`
- [x] 1 summary report in `results/benchmark_summary_*.txt`
- [x] 1 analysis JSON in `results/analysis_summary.json`
- [x] Status file showing "COMPLETE"

### Verify Results

```bash
# Count files
find results/ -name "*.csv" | wc -l    # Should be 20
find data/videos/ -name "*.mp4" | wc -l  # Should be 10
find logs/ -name "*.log" | wc -l        # Should be 20+

# Check file sizes
du -sh results/                         # Should be ~50MB
du -sh data/videos/                     # Should be ~100MB

# Verify CSV contents
head -5 results/paper1/x86/static_scene_*.csv
# Should show: frameId,timestamp,latencyMs,inferenceMs,detections,...
```

---

## 🚀 Ready to Start?

**Just run this command and wait ~2 hours:**

```bash
cd ~/Dapps-Empty/2026/Oct2026/gravisonde
./automated-benchmark-runner.sh
```

**Monitor in another terminal:**

```bash
watch -n 5 cat benchmark_status.txt
```

**Then analyze:**

```bash
python3 analyze_results.py results/
```

**Done! You now have complete academic datasets for 3 papers.**

---

## 📚 Reference Documents

- **Full details:** `AUTOMATED_RUNNER_GUIDE.md`
- **Academic plan:** `ACADEMIC_DATA_COLLECTION_PLAN.md`
- **Local setup:** `LOCAL_SETUP_GUIDE.md`
- **EC2 fix:** `FIX_REMOTE_DEPLOYMENT.md`

---

**Questions? Check the logs:**
- Progress: `benchmark_progress.log`
- Errors: `logs/bench_*.log`
- Summary: `results/benchmark_summary_*.txt`
