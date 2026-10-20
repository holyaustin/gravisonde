# Reproduction Guide

This guide provides step-by-step instructions to reproduce Gravisonde locally and on AWS.

---

## 1. Prerequisites

- **OS:** Linux, macOS, or Windows with WSL2
- **Docker:** >= 24.0
- **Node.js:** >= 22 (for dashboard)
- **Python:** >= 3.10 (for pipeline)
- **AWS CLI:** configured with credentials
- **AWS CDK:** v2.x installed (`npm i -g aws-cdk`)

---

## 2. Local Development

### 2.1 Clone & Navigate

```bash
git clone <repo-url>
cd gravisonde
```

### 2.2 Create Environment File

```bash
cp .env.example .env
# Edit .env if needed (LEADERBOARD_ID for leaderboard API)
```

### 2.3 Start Local Stack

```bash
make local-up
```

This runs:

| Service | Port | Purpose |
|---------|------|---------|
| dashboard | 3000 | Next.js app with SSE metrics |
| pipeline | N/A | Stub OpenCV 5 pipeline (simulated) |
| localstack | 4566 | Mock AWS (CloudWatch, S3) |

### 2.4 Verify

Open http://localhost:3000 in your browser. You should see the dashboard with:

- Live metrics cards (FPS, latency, cost)
- Charts updating in real-time
- Download button for benchmark CSV

### 2.5 Stop Local Stack

```bash
make local-down
```

---

## 3. AWS Deployment

### 3.1 Bootstrap CDK (once per account/region)

```bash
cd infra
make bootstrap
```

This creates the CDK bootstrapped resources (bucket, lambda, etc.).

### 3.2 Deploy Infrastructure

```bash
make deploy-infra
```

CDK outputs:
- `InstanceId` — EC2 instance ID
- `InstancePublicIp` — Public IP of the pipeline server
- `BenchmarkBucketName` — S3 bucket for CSV artifacts
- `CwLogGroup` — CloudWatch log group

### 3.3 Build & Push Pipeline Images

```bash
make build-pipeline
make push-pipeline
```

This builds:
- `cv-pipeline:cool` — COOL runtime image (for EC2)
- `cv-pipeline:stock` — Stock OpenCV 5 image (for comparison)

### 3.4 Start Pipeline on EC2

```bash
make start-pipeline
```

The pipeline starts via AWS Systems Manager (SSM) and begins streaming metrics to CloudWatch and S3.

### 3.5 Run Benchmark

```bash
make benchmark
```

Runs COOL vs Stock for a fixed duration and uploads CSV to the S3 bucket.

---

## 4. Verification Checklist

| Step | How to Verify |
|------|---------------|
| Dashboard loads | http://localhost:3000 or https://gravisonde.demo |
| SSE stream active | Network tab → ws://localhost:3000/api/metrics |
| Pipeline running | Check EC2 instance status in AWS console |
| Metrics in CloudWatch | CW namespace `Gravisonde` |
| CSV in S3 | `aws s3 ls s3://gravisonde-benchmarks-<id>/` |

---

## 5. Troubleshooting

| Symptom | Fix |
|---------|-----|
| Dashboard shows "No data" | Ensure pipeline is running (`make start-pipeline`) |
| LocalStack connection refused | `make local-down && make local-up` |
| Python import errors | `pip install -r apps/cv-pipeline/requirements.txt` |
| TypeScript errors | `cd apps/dashboard && npm install && npx tsc --noEmit` |
| CDK synth fails | Check `coolAmiId` parameter is set in `bin/gravisonde.ts` |

---

## 6. Clean Up

```bash
make destroy-infra   # Remove CDK stack
make local-down      # Stop Docker compose
```

---

## 7. Re-create Sample Video

The sample video is hosted in `docker-compose.yml` volume mount:

```yaml
volumes:
  - ./sample_video.mp4:/data/sample.mp4:ro
```

If the file is missing or 0 bytes, generate a test video:

```bash
ffmpeg -f lavfi -i testsrc=duration=30:size=640x480:rate=30 -c:v libx264 -preset fast output.mp4
mv output.mp4 sample_video.mp4
```

Or download a CC0 test video:

```bash
wget https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4 -O sample_video.mp4
```