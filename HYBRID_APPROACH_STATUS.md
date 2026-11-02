# Hybrid Approach - x86 Now, ARM Later

**Date:** 2026-11-02  
**Strategy:** Get Papers 2 & 3 data now, Paper 1 ARM data later

---

## What's Running Now (x86-Only)

### Modified Script Configuration
- ✅ **Platforms:** x86 only (ARM disabled)
- ✅ **Tests:** 10 tests × 5 minutes = 50 minutes
- ✅ **Output:** 10 CSV files with x86 performance data

### Test Matrix (x86-Only)

| Paper | Videos | Tests | Data Output |
|-------|--------|-------|-------------|
| **Paper 1** | 3 videos | 3 x86 tests | Baseline x86 data |
| **Paper 2** | 3 videos | 3 x86 tests | ✅ Complete for paper |
| **Paper 3** | 4 videos | 4 x86 tests | ✅ Complete for paper |
| **Total** | 10 videos | 10 tests | 50 minutes |

---

## What You'll Get (In ~50 Minutes)

### Complete Data For:

**Paper 2: Cost-Aware Edge Inference** ✅
- Detection-heavy workload (x86)
- Feature-heavy workload (x86)
- Balanced workload (x86)
- **Status:** Ready to write paper immediately

**Paper 3: ALIKED vs ORB Feature Detectors** ✅
- High-texture scene (x86)
- Low-texture scene (x86)
- Lighting changes (x86)
- Motion blur (x86)
- **Status:** Ready to write paper immediately

### Partial Data For:

**Paper 1: Architecture Comparison** ⏳
- x86 baseline data ✅
- ARM Graviton4 data ⏳ (pending EC2)
- **Status:** Need ARM data from real hardware

---

## Phase 2: Getting ARM Data for Paper 1

### After x86 Tests Complete (Later Today/Tomorrow)

**Step 1: Fix EC2 SSH (10 minutes)**
```bash
# Option A: AWS Console
1. Go to EC2 Console → Security Groups
2. Find security group for instance 16.16.75.56
3. Add inbound rule: SSH (port 22) from My IP
4. Test: ssh -i ~/.ssh/gravisonde-aws-key1.pem ec2-user@16.16.75.56

# Option B: AWS CLI
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 22 \
  --cidr YOUR_IP/32 \
  --region eu-north-1
```

**Step 2: Deploy to Graviton4 (20 minutes)**
```bash
# SSH to EC2
ssh -i ~/.ssh/gravisonde-aws-key1.pem ec2-user@16.16.75.56

# Clone repo and setup
git clone <your-repo> && cd gravisonde
docker compose build

# Download YOLO model
wget -O data/yolo11n.onnx \
  "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.onnx"

# Copy Paper 1 videos from local to EC2
# (From local machine)
scp -i ~/.ssh/gravisonde-aws-key1.pem -r \
  data/videos/paper1/ \
  ec2-user@16.16.75.56:~/gravisonde/data/videos/
```

**Step 3: Run Paper 1 Tests on Graviton4 (15 minutes)**
```bash
# On EC2 Graviton4 instance
cd ~/gravisonde

# Run only Paper 1 tests (3 videos × 5 min = 15 min)
docker compose down
for video in static_scene dynamic_scene dense_objects; do
  # Update docker-compose.yml to use current video
  sed -i "s|sample1.mp4|paper1/${video}.mp4|" docker-compose.yml
  
  # Run for 5 minutes
  docker compose up -d pipeline
  sleep 300
  
  # Export results
  ./export-metrics-csv.sh "results/paper1/arm/${video}_graviton4_$(date +%Y%m%d_%H%M%S).csv"
  
  docker compose down
done
```

**Step 4: Download ARM Results (5 minutes)**
```bash
# From local machine
scp -i ~/.ssh/gravisonde-aws-key1.pem -r \
  ec2-user@16.16.75.56:~/gravisonde/results/paper1/arm/ \
  ./results/paper1/
```

**Total Phase 2 Time:** ~50 minutes

---

## Timeline

### Today (Current Time: 09:30 AM)

| Time | Activity | Status |
|------|----------|--------|
| 09:30 | Start x86-only script | 🔄 Starting now |
| 10:20 | x86 tests complete | 🎯 ~50 min |
| 10:30 | Analyze Papers 2 & 3 data | ✅ Ready to write |

### Later (When EC2 SSH Fixed)

| Time | Activity | Duration |
|------|----------|----------|
| -- | Fix EC2 security group | 10 min |
| -- | Deploy to Graviton4 | 20 min |
| -- | Run Paper 1 ARM tests | 15 min |
| -- | Download results | 5 min |
| **Total** | **Complete Paper 1** | **50 min** |

---

## Current Run Status

**What's happening right now:**
```bash
# Running: automated-benchmark-runner.sh (x86-only)
# Expected completion: ~10:20 AM
# Output: 10 CSV files in results/paper*/x86/
```

**Monitor progress:**
```bash
# Terminal 1: Watch status
watch -n 5 cat benchmark_status.txt

# Terminal 2: Follow logs
tail -f benchmark_progress.log

# Check what's running
docker ps
```

---

## Expected Results Structure

After this run completes:

```
results/
├── paper1/
│   └── x86/
│       ├── static_scene_20261102_093500.csv      ✓ Baseline
│       ├── dynamic_scene_20261102_094000.csv     ✓ Baseline
│       └── dense_objects_20261102_094500.csv     ✓ Baseline
├── paper2/
│   └── x86/
│       ├── detection_heavy_20261102_095000.csv   ✓ Complete
│       ├── feature_heavy_20261102_095500.csv     ✓ Complete
│       └── balanced_20261102_100000.csv          ✓ Complete
└── paper3/
    └── x86/
        ├── high_texture_20261102_100500.csv      ✓ Complete
        ├── low_texture_20261102_101000.csv       ✓ Complete
        ├── lighting_change_20261102_101500.csv   ✓ Complete
        └── motion_blur_20261102_102000.csv       ✓ Complete
```

**Missing (will add later):**
```
results/paper1/arm/  ← Need Graviton4 data
```

---

## Immediate Next Steps

### 1. Let Current Script Finish (~50 min)
```bash
# Already running - just wait
# Monitor: tail -f benchmark_progress.log
```

### 2. Analyze x86 Results
```bash
# After completion (~10:20 AM)
python3 analyze_results.py results/

# This will show:
# - Paper 2: Complete analysis ✅
# - Paper 3: Complete analysis ✅
# - Paper 1: x86 baseline only (ARM pending)
```

### 3. Start Writing Papers 2 & 3
You have complete data for these papers:
- Paper 2: Cost-efficiency analysis
- Paper 3: Feature detector comparison

### 4. Fix EC2 SSH (Parallel Work)
While analyzing data, fix EC2 access:
- See: `FIX_REMOTE_DEPLOYMENT.md`
- Security group issue (port 22)
- Takes 10-15 minutes

### 5. Complete Paper 1 on Graviton4
Once SSH works, run Paper 1 tests (~50 min)

---

## Summary

### What You're Getting Now
- ✅ **10 x86 datasets** (50 minutes)
- ✅ **Papers 2 & 3 complete** (ready to write)
- ✅ **Paper 1 x86 baseline** (half done)

### What You Need Later
- ⏳ **Paper 1 ARM data** from Graviton4 (50 minutes)
- 🔧 **Fix EC2 SSH first** (10 minutes)

### Total Time Investment
- **Now:** 50 minutes (running)
- **Later:** 60 minutes (SSH fix + ARM tests)
- **Total:** 110 minutes across 2 sessions

### Academic Output
- 📄 **3 complete papers** with real data
- 📊 **All 10 test scenarios** covered
- 🎯 **Publication-ready** datasets

---

## Current Status

**Script is now configured for x86-only testing.**

**Run it now:**
```bash
./automated-benchmark-runner.sh
```

**Expected completion:** ~10:20 AM  
**Next checkpoint:** Analyze results and start writing Papers 2 & 3
