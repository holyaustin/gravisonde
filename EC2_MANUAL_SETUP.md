# EC2 Graviton4 Setup - Manual Steps for Paper 1

**Date:** 2026-11-02  
**Time:** ~20 minutes total  
**Goal:** Update EC2 repo and run Paper 1 ARM tests

---

## Prerequisites

✅ SSH to EC2 is working  
✅ Code pushed to GitHub  
✅ Paper 1 videos exist locally in `data/videos/paper1/`

---

## Step-by-Step Instructions

### **Step 1: SSH to EC2 (30 seconds)**

```bash
ssh -i /home/augustineonuora/.ssh/gravisonde-aws-key1.pem ec2-user@16.16.75.56
```

---

### **Step 2: Update/Clone Repo on EC2 (2 minutes)**

Once on EC2:

```bash
# Check if repo exists
cd ~
ls gravisonde

# If repo exists - UPDATE IT:
cd ~/gravisonde
git pull origin main
# (or: git pull origin master if that's your branch name)

# If repo doesn't exist - CLONE IT:
git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git gravisonde
cd gravisonde
```

**Replace YOUR_USERNAME and YOUR_REPO_NAME with your actual GitHub details!**

---

### **Step 3: Copy Paper 1 Videos to EC2 (3 minutes)**

**Open a NEW terminal on your LOCAL machine** (keep EC2 SSH open in the first terminal):

```bash
# On LOCAL machine - copy videos to EC2
cd ~/Dapps-Empty/2026/Oct2026/gravisonde

# Create directory on EC2
ssh -i /home/augustineonuora/.ssh/gravisonde-aws-key1.pem ec2-user@16.16.75.56 \
    "mkdir -p ~/gravisonde/data/videos/paper1"

# Copy all Paper 1 videos
scp -i /home/augustineonuora/.ssh/gravisonde-aws-key1.pem \
    data/videos/paper1/*.mp4 \
    ec2-user@16.16.75.56:~/gravisonde/data/videos/paper1/
```

**Expected output:** 3 videos transferred (~6MB total)

---

### **Step 4: Download YOLO Model on EC2 (1 minute)**

**Back to EC2 SSH terminal:**

```bash
cd ~/gravisonde
mkdir -p data

# Download YOLO model (~10MB)
wget -O data/yolo11n.onnx \
    "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.onnx"

# Verify download
ls -lh data/yolo11n.onnx
# Should show: ~10.4M
```

---

### **Step 5: Build Docker Image (5 minutes)**

**On EC2:**

```bash
cd ~/gravisonde

# Make sure Docker is running
sudo systemctl start docker
sudo systemctl status docker

# Build the pipeline image
docker compose build pipeline

# This takes 3-5 minutes on first build
```

**Wait for:** "Successfully built" message

---

### **Step 6: Run Paper 1 Tests (15 minutes - 3 tests × 5 min each)**

**On EC2, run these commands ONE AT A TIME:**

#### **Test 1: static_scene**

```bash
cd ~/gravisonde

# Stop any running containers
docker compose down

# Update docker-compose.yml to use static_scene video
sed -i 's|sample1.mp4|paper1/static_scene.mp4|g' docker-compose.yml

# Start pipeline
docker compose up -d pipeline

# Watch logs (Ctrl+C to exit, container keeps running)
docker compose logs -f pipeline

# Wait 5 minutes, then export and stop
# (After 5 minutes, press Ctrl+C and continue)
```

**After 5 minutes:**
```bash
# Export metrics
./export-metrics-csv.sh results/paper1/arm/static_scene_graviton4_$(date +%Y%m%d_%H%M%S).csv

# Stop container
docker compose down
```

#### **Test 2: dynamic_scene**

```bash
# Update to dynamic_scene video
sed -i 's|static_scene.mp4|dynamic_scene.mp4|g' docker-compose.yml

# Start pipeline
docker compose up -d pipeline

# Wait 5 minutes
sleep 300

# Export and stop
./export-metrics-csv.sh results/paper1/arm/dynamic_scene_graviton4_$(date +%Y%m%d_%H%M%S).csv
docker compose down
```

#### **Test 3: dense_objects**

```bash
# Update to dense_objects video
sed -i 's|dynamic_scene.mp4|dense_objects.mp4|g' docker-compose.yml

# Start pipeline
docker compose up -d pipeline

# Wait 5 minutes
sleep 300

# Export and stop
./export-metrics-csv.sh results/paper1/arm/dense_objects_graviton4_$(date +%Y%m%d_%H%M%S).csv
docker compose down
```

---

### **Step 7: Download Results to Local Machine (2 minutes)**

**On LOCAL machine (new terminal):**

```bash
cd ~/Dapps-Empty/2026/Oct2026/gravisonde

# Create local results directory
mkdir -p results/paper1/arm

# Download all ARM results from EC2
scp -i /home/augustineonuora/.ssh/gravisonde-aws-key1.pem -r \
    ec2-user@16.16.75.56:~/gravisonde/results/paper1/arm/*.csv \
    results/paper1/arm/

# Verify downloads
ls -lh results/paper1/arm/
```

**Expected:** 3 CSV files with Graviton4 ARM data

---

## Verification

### Check Results Structure

```bash
# On LOCAL machine
tree results/paper1/

# Should show:
# results/paper1/
# ├── arm/
# │   ├── static_scene_graviton4_20261102_143000.csv
# │   ├── dynamic_scene_graviton4_20261102_144000.csv
# │   └── dense_objects_graviton4_20261102_145000.csv
# └── x86/
#     ├── static_scene_20261102_103000.csv
#     ├── dynamic_scene_20261102_104000.csv
#     └── dense_objects_20261102_105000.csv
```

---

## Quick Analysis

```bash
# On LOCAL machine
python3 analyze_results.py results/

# You should now see BOTH x86 and ARM results for Paper 1!
```

---

## Timeline

| Step | Time | Total |
|------|------|-------|
| SSH to EC2 | 30s | 0:30 |
| Update repo | 2 min | 2:30 |
| Copy videos | 3 min | 5:30 |
| Download YOLO | 1 min | 6:30 |
| Build Docker | 5 min | 11:30 |
| Test 1 (static) | 5 min | 16:30 |
| Test 2 (dynamic) | 5 min | 21:30 |
| Test 3 (dense) | 5 min | 26:30 |
| Download results | 2 min | 28:30 |

**Total: ~30 minutes**

---

## What You'll Have

✅ **Paper 1:** Complete (x86 + ARM Graviton4 data)  
✅ **Paper 2:** Complete (x86 data)  
✅ **Paper 3:** Complete (x86 data)  

**All 3 academic papers ready to write!** 🎉

---

## Troubleshooting

### If git pull fails
```bash
cd ~/gravisonde
git fetch origin
git reset --hard origin/main  # Force update to latest
```

### If export-metrics-csv.sh doesn't exist on EC2
```bash
# Create it manually or just save docker logs
docker compose logs pipeline > results/paper1/arm/test_$(date +%s).log
```

### If Docker build fails
```bash
# Check Docker is running
sudo systemctl restart docker
sudo usermod -aG docker ec2-user
# Logout and login again, then retry
```

### If videos not found
```bash
# Verify videos are on EC2
ls -lh ~/gravisonde/data/videos/paper1/
# Should show 3 .mp4 files
```

---

## Current Time: 14:20 (2:20 PM)

**If you start now:**
- 14:50 (2:50 PM) - All tests complete
- 15:00 (3:00 PM) - Data analyzed
- **Ready to write all 3 papers by 3:00 PM!**

---

## Start Now!

```bash
# Step 1: SSH to EC2
ssh -i /home/augustineonuora/.ssh/gravisonde-aws-key1.pem ec2-user@16.16.75.56
```

Then follow steps 2-7 above! 🚀
