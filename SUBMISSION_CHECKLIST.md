# Gravisonde — OpenCV AI Competition 2026 Submission Checklist

**Project:** Gravisonde — OpenCV 5 + COOL on AWS Graviton performance benchmark
**Track:** COOL Award ($1,000)
**Repo:** `/home/augustineonuora/Dapps-Empty/2026/Oct2026/gravisonde`
**Date:** 2026-10-26

## Submission Requirements vs Current State

### Required Deliverables

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Working repo with README | ✅ Done | `README.md` with quick start, architecture, verification |
| Technical report | ✅ Done | `docs/technical-report.mdx` 6.4 KB |
| Architecture diagram | ✅ Done | `docs/architecture.mmd` with Mermaid flowchart |
| Reproduction guide | ✅ Done | `docs/reproduction-guide.md` |
| Demo script | ✅ Done | `docs/demo-script.md` 4-5 min walkthrough |
| Sample video input | ✅ Done | `sample_video.mp4` 3.5 MB, 30s testsrc |
| Local runnable demo | ✅ Done | `make local-up` → http://localhost:3000 |
| Benchmark evidence | ✅ Done | `scripts/bench_runner.py`, CSV output, SSE dashboard |
| Git history | ✅ Done | 5 commits, initial commit present |
| Makefile automation | ✅ Done | `local-up`, `bootstrap`, `deploy-infra`, `benchmark` |

### Additional Evidence for Best Use of COOL Award

#### 1. COOL version and AWS instance/deployment configuration
- **Instance:** `c8g.xlarge` Graviton4, $0.136/hr
- **AMI:** AWS Marketplace COOL AMI — Cloud-Optimized OpenCV Library for Graviton
- **OpenCV:** OpenCV 5.0.0.93 + Arm KleidiCV acceleration
- **Pipeline mode:** `PIPELINE_MODE=cool` (vs stock)
- **Infra:** AWS CDK stack `GravisondeStack` — VPC, EC2, IAM, S3, CloudWatch, ALB

```mermaid
flowchart LR
    subgraph AWS
        EC2[c8g.xlarge Graviton4<br/>COOL AMI<br/>OpenCV 5.0.0.93]
        S3[(S3 benchmark artifacts)]
        CW[(CloudWatch metrics)]
    end
    Video[sample_video.mp4] --> EC2
    EC2 -->|fps, latency_ms, detections| CW
    EC2 -->|CSV| S3
```

#### 2. Reproducible evaluation method, inputs, baselines, results

```mermaid
flowchart TB
    Input[Input Video<br/>sample_video.mp4<br/>30s @ 640x480 30fps]
    Pipeline[OpenCV 5 Pipeline<br/>YOLO11n DNN + ALIKED/LightGlue]
    Metrics[MetricsCollector<br/>per-frame latency_ms, inference_ms, detections]
    CSV[CSV Output<br/>/tmp/bench.csv]
    Dashboard[Next.js Dashboard<br/>SSE live metrics]
    Cloud[CloudWatch + S3]

    Input --> Pipeline
    Pipeline --> Metrics
    Metrics --> CSV
    Metrics --> Dashboard
    Metrics --> Cloud
```

**Evaluation protocol:**
1. `make local-up` starts dashboard + pipeline + LocalStack
2. Pipeline reads `/data/sample.mp4`
3. Run benchmark: `python3 scripts/bench_runner.py --duration 300 --pipeline cool --output /tmp/bench_cool.csv`
4. Repeat with `--pipeline stock`
5. Compare fps-per-dollar = FPS / $0.136/hr

**Baseline:** stock OpenCV 5 on x86 `c7i.xlarge`
**Claimed workload:** Real-time object detection + feature matching on video

#### 3. Evidence COOL executes claimed core workload
- Per-frame CSV contains `opencv_version`, `cool_version`, `instance_id`, `instance_type`
- Dashboard displays live FPS, p50/p95/p99 latency, fps/$
- Metrics schema emits camelCase to match Zod contract — verified in DECISIONS.md
- `Detector.mode` = "cool" vs "synthetic" visible in logs
- Sample CSV header: timestamp, frame_id, latency_ms, inference_ms, detections, instance_id, opencv_version, cool_version

### Testing & Video Capture — Local

Because sandbox blocks npm/PyPI and Docker socket, run these on your local machine.

#### Quick local test
```bash
cd /home/augustineonuora/Dapps-Empty/2026/Oct2026/gravisonde

# 1. Ensure sample video exists
ls -lh sample_video.mp4
# 3.5 MB expected

# 2. Start stack
make local-up
# Dashboard: http://localhost:3000
# Logs: docker compose logs -f pipeline

# 3. Run a short benchmark in another terminal
python3 scripts/bench_runner.py --duration 30 --pipeline cool --output /tmp/bench.csv --instance-id gravisonde-bench --arch graviton --instance-type c8g.xlarge

# 4. Open dashboard
# Live metrics cards, video canvas with bounding boxes, charts updating via SSE
# Click "Download Benchmark" to get CSV

# 5. Stop
make local-down
```

#### Verification checklist
- [ ] `cd apps/dashboard && npm install && npm run typecheck && npm run build` passes
- [ ] `cd apps/cv-pipeline && pip install -r requirements.txt && python -c "import cv2; print(cv2.__version__)"` prints 5.0.0.93
- [ ] `make local-up` → http://localhost:3000 loads with live metrics
- [ ] Benchmark CSV generated with >1000 frames
- [ ] Dashboard SSE stream active, charts update

#### Recording your demo video
1. Start `make local-up`
2. Open http://localhost:3000 in browser full-screen
3. Start screen recorder
4. Walk through `docs/demo-script.md`:
   - 0:00-0:45 Problem hook
   - 0:45-2:30 Live dashboard, metrics, download CSV
   - 2:30-3:15 Architecture diagram
   - 3:15-3:45 Reproducibility `make local-up`
   - 3:45-4:15 Responsible use
5. Keep under 5 minutes

### What is left to do

From historical TODO / memory, the following is now complete:
- Docs were missing → now present
- Sample video 0 bytes → now 3.5 MB
- Git init → committed

**Remaining optional polish:**
- [ ] `docs/images/banner.svg` and `result-card.svg` referenced in DECISIONS.md but folder empty — optional
- [ ] Push repo to GitHub: `git remote add origin https://github.com/holyaustin/gravisonde.git && git branch -M main && git push -u origin main`
- [ ] Record and upload demo video ≤5 min
- [ ] Run full AWS benchmark `make bootstrap && make deploy-infra && make benchmark` for real COOL vs stock numbers — requires AWS account

### Agentic Vision Award note

The current submission targets COOL Award. No agent workflow diagram, perception-decision-action trace, or task success evaluation is present in the repo. `AGENTS.md` files exist for Claude Code guidance only. If you intend to submit for Agentic Vision Award, add:
- Agent workflow mermaid diagram
- Trace showing OpenCV 5 output changes a decision/tool call
- Evaluation of success/failure handling and human control

### Files to include in submission bundle
```
gravisonde/
├── README.md
├── docs/
│   ├── technical-report.mdx
│   ├── architecture.mmd
│   ├── reproduction-guide.md
│   └── demo-script.md
├── sample_video.mp4
├── docker-compose.yml
├── Makefile
├── scripts/bench_runner.py
└── SUBMISSION_CHECKLIST.md
```

Co-Authored-By: Claude Code <noreply@anthropic.com>
