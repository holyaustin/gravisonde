#!/bin/bash
# generate_test_videos.sh
# Creates synthetic test videos for academic papers
# Usage: ./generate_test_videos.sh

set -e

echo "=========================================="
echo "Academic Test Video Generator"
echo "=========================================="
echo ""

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "ERROR: ffmpeg not found. Install with:"
    echo "  sudo apt-get install ffmpeg"
    exit 1
fi

# Create directories
mkdir -p data/videos/{paper1,paper2,paper3}

echo "Generating test videos (this may take a few minutes)..."
echo ""

# =============================================================================
# Paper 1: Architecture Comparison (ARM vs x86)
# Use SAME videos on both architectures
# =============================================================================
echo "📹 Paper 1: Architecture Comparison Videos"

# Video 1: Static Scene (Low Motion)
echo "  - Generating static_scene.mp4 (5 min, 640x480@30fps)..."
ffmpeg -f lavfi -i testsrc=duration=300:size=640x480:rate=30 \
  -vf "drawtext=text='Static Scene - Paper 1':fontsize=20:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5" \
  -c:v libx264 -preset fast -y data/videos/paper1/static_scene.mp4 2>&1 | grep -v "frame=" || true

# Video 2: Dynamic Scene (High Motion)
echo "  - Generating dynamic_scene.mp4 (5 min, moving objects)..."
ffmpeg -f lavfi -i testsrc=duration=300:size=640x480:rate=30 \
  -vf "drawbox=x='50+150*sin(t)':y='100+50*cos(t)':w=80:h=80:color=red@0.7:t=fill,
       drawbox=x='200+100*cos(t*1.5)':y='150+80*sin(t*1.5)':w=60:h=60:color=blue@0.7:t=fill,
       drawbox=x='400+120*sin(t*0.8)':y='250+60*cos(t*0.8)':w=70:h=70:color=green@0.7:t=fill,
       drawtext=text='Dynamic Scene - Paper 1':fontsize=20:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5" \
  -c:v libx264 -preset fast -y data/videos/paper1/dynamic_scene.mp4 2>&1 | grep -v "frame=" || true

# Video 3: Dense Objects Scene
echo "  - Generating dense_objects.mp4 (5 min, many objects)..."
ffmpeg -f lavfi -i testsrc=duration=300:size=640x480:rate=30 \
  -vf "drawbox=x=50:y=50:w=80:h=80:color=red@0.6:t=fill,
       drawbox=x=200:y=50:w=80:h=80:color=blue@0.6:t=fill,
       drawbox=x=350:y=50:w=80:h=80:color=green@0.6:t=fill,
       drawbox=x=50:y=200:w=80:h=80:color=yellow@0.6:t=fill,
       drawbox=x=200:y=200:w=80:h=80:color=magenta@0.6:t=fill,
       drawbox=x=350:y=200:w=80:h=80:color=cyan@0.6:t=fill,
       drawbox=x=50:y=350:w=80:h=80:color=orange@0.6:t=fill,
       drawbox=x=200:y=350:w=80:h=80:color=purple@0.6:t=fill,
       drawtext=text='Dense Objects - Paper 1':fontsize=20:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5" \
  -c:v libx264 -preset fast -y data/videos/paper1/dense_objects.mp4 2>&1 | grep -v "frame=" || true

echo "✓ Paper 1 videos complete (3 videos, 15 min total)"
echo ""

# =============================================================================
# Paper 2: Cost-Efficiency (FPS-per-Dollar)
# Use DIFFERENT workload characteristics
# =============================================================================
echo "📹 Paper 2: Cost-Efficiency Videos"

# Video 1: Detection-Heavy (DNN-dominant workload)
echo "  - Generating detection_heavy.mp4 (5 min, many objects)..."
ffmpeg -f lavfi -i testsrc=duration=300:size=640x480:rate=30 \
  -vf "drawbox=x='50+mod(t*50\,500)':y=100:w=60:h=60:color=red@0.7:t=fill,
       drawbox=x='150+mod(t*70\,450)':y=150:w=60:h=60:color=blue@0.7:t=fill,
       drawbox=x='250+mod(t*90\,400)':y=200:w=60:h=60:color=green@0.7:t=fill,
       drawbox=x='350+mod(t*60\,350)':y=250:w=60:h=60:color=yellow@0.7:t=fill,
       drawbox=x='100+mod(t*80\,450)':y=300:w=60:h=60:color=cyan@0.7:t=fill,
       drawtext=text='Detection Heavy - Paper 2':fontsize=20:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5" \
  -c:v libx264 -preset fast -y data/videos/paper2/detection_heavy.mp4 2>&1 | grep -v "frame=" || true

# Video 2: Feature-Heavy (ALIKED+LightGlue dominant workload)
echo "  - Generating feature_heavy.mp4 (5 min, high texture)..."
ffmpeg -f lavfi -i mandelbrot=duration=300:size=640x480:rate=30 \
  -vf "drawtext=text='Feature Heavy - Paper 2':fontsize=20:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5" \
  -c:v libx264 -preset fast -y data/videos/paper2/feature_heavy.mp4 2>&1 | grep -v "frame=" || true

# Video 3: Balanced Workload
echo "  - Generating balanced.mp4 (5 min, mixed)..."
ffmpeg -f lavfi -i testsrc=duration=300:size=640x480:rate=30 \
  -vf "drawbox=x='100+100*sin(t)':y='150+50*cos(t)':w=80:h=80:color=red@0.6:t=fill,
       drawbox=x='300+80*cos(t*1.2)':y='200+60*sin(t*1.2)':w=70:h=70:color=blue@0.6:t=fill,
       drawtext=text='Balanced - Paper 2':fontsize=20:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5" \
  -c:v libx264 -preset fast -y data/videos/paper2/balanced.mp4 2>&1 | grep -v "frame=" || true

echo "✓ Paper 2 videos complete (3 videos, 15 min total)"
echo ""

# =============================================================================
# Paper 3: Feature Detector Comparison (ALIKED vs ORB)
# Use DIFFERENT feature characteristics
# =============================================================================
echo "📹 Paper 3: Feature Detector Comparison Videos"

# Video 1: High Texture (ALIKED should excel)
echo "  - Generating high_texture.mp4 (5 min, complex patterns)..."
ffmpeg -f lavfi -i mandelbrot=duration=300:size=640x480:rate=30 \
  -vf "drawtext=text='High Texture - Paper 3':fontsize=20:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5" \
  -c:v libx264 -preset fast -y data/videos/paper3/high_texture.mp4 2>&1 | grep -v "frame=" || true

# Video 2: Low Texture (ORB sufficient)
echo "  - Generating low_texture.mp4 (5 min, uniform surfaces)..."
ffmpeg -f lavfi -i color=c=skyblue:duration=300:size=640x480:rate=30 \
  -vf "drawbox=x=200:y=180:w=240:h=120:color=white@0.8:t=fill,
       drawtext=text='Low Texture - Paper 3':fontsize=20:x=10:y=10:fontcolor=black:box=1:boxcolor=white@0.5" \
  -c:v libx264 -preset fast -y data/videos/paper3/low_texture.mp4 2>&1 | grep -v "frame=" || true

# Video 3: Lighting Changes
echo "  - Generating lighting_change.mp4 (5 min, brightness variation)..."
ffmpeg -f lavfi -i testsrc=duration=300:size=640x480:rate=30 \
  -vf "eq=brightness='0.5*sin(t/10)':contrast=1.5,
       drawtext=text='Lighting Change - Paper 3':fontsize=20:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5" \
  -c:v libx264 -preset fast -y data/videos/paper3/lighting_change.mp4 2>&1 | grep -v "frame=" || true

# Video 4: Motion Blur
echo "  - Generating motion_blur.mp4 (5 min, fast movement)..."
ffmpeg -f lavfi -i testsrc=duration=300:size=640x480:rate=30 \
  -vf "boxblur=luma_radius=3:luma_power=1,
       drawbox=x='50+400*sin(t*2)':y=200:w=80:h=80:color=red@0.7:t=fill,
       drawtext=text='Motion Blur - Paper 3':fontsize=20:x=10:y=10:fontcolor=white:box=1:boxcolor=black@0.5" \
  -c:v libx264 -preset fast -y data/videos/paper3/motion_blur.mp4 2>&1 | grep -v "frame=" || true

echo "✓ Paper 3 videos complete (4 videos, 20 min total)"
echo ""

# =============================================================================
# Summary
# =============================================================================
echo "=========================================="
echo "✓ All test videos generated successfully!"
echo "=========================================="
echo ""
echo "Videos created:"
echo ""
echo "Paper 1 (Architecture Comparison):"
find data/videos/paper1 -name "*.mp4" -exec ls -lh {} \; | awk '{print "  - " $9 " (" $5 ")"}'
echo ""
echo "Paper 2 (Cost-Efficiency):"
find data/videos/paper2 -name "*.mp4" -exec ls -lh {} \; | awk '{print "  - " $9 " (" $5 ")"}'
echo ""
echo "Paper 3 (Feature Detectors):"
find data/videos/paper3 -name "*.mp4" -exec ls -lh {} \; | awk '{print "  - " $9 " (" $5 ")"}'
echo ""
echo "Total videos: 10"
echo "Total duration: ~50 minutes"
echo ""
echo "Next steps:"
echo "  1. Run benchmarks: ./run-paper-benchmarks.sh"
echo "  2. Export metrics: ./export-metrics-csv.sh results/paper1_test.csv"
echo "  3. Analyze data: See ACADEMIC_DATA_COLLECTION_PLAN.md"
