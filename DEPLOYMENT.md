# Gravisonde — Deployment Guide

Two parts:

- **Part A** reproduces the working local stack (Docker Desktop on Ubuntu): Next.js dashboard + OpenCV 5 pipeline + LocalStack.
- **Part B** deploys it remotely: dashboard on **Vercel**, pipeline on **AWS EC2**, data in real **CloudWatch + S3**.

> Items marked **[VERIFY]** depend on code I have not seen (the dashboard's AWS client code, `main.py`, `next.config.ts`). Check them before relying on that step.

---

## Contents

- [Part A: Reproduce the local deployment](#part-a-reproduce-the-local-deployment)
- [Part B: Deploy remotely (Vercel + AWS)](#part-b-deploy-remotely-vercel--aws)

---

# Part A: Reproduce the local deployment

## A0. What runs and why it is built this way

| Service | Port | What it is |
|---|---|---|
| `dashboard` | 3000 | Next.js 16 app (standalone output) |
| `pipeline` | none | Python 3.11, OpenCV 5.0.0.93, onnxruntime 1.19.2 |
| `localstack` | 4566 | Mock AWS (CloudWatch, S3, EC2, Pricing) |

Two decisions come from problems met on a slow, flaky connection:

1. **Dashboard is built on the host, then packaged by Docker.** Inside Docker, Next.js 16's default bundler (Turbopack) failed on Tailwind's native modules (`lightningcss`, `@tailwindcss/oxide`). Building with `--webpack` works. The Docker image only copies the finished `.next/standalone` output.
2. **Pipeline wheels are downloaded on the host**, then installed offline in Docker. Docker Desktop's VM network was far slower than the host, and a 69 MB wheel kept timing out.

If you have a fast, stable connection you can skip the offline tricks (see A5 "Fast-network alternative").

## A1. Prerequisites

| Tool | Version | Check |
|---|---|---|
| Ubuntu | 24.04 or 26.04 (x86-64) | `lsb_release -d` |
| Docker Desktop | 4.59+ (4.96.x tested for upgrade) | `docker version` |
| Node.js | 20.9+ (22 recommended) | `node -v` |
| npm | 10+ | `npm -v` |
| Python + pip (host) | 3.9+ (only to download wheels) | `python3 -m pip --version` |
| git | any | `git --version` |
| Free disk | about 10 GB | `df -h .` |

Make sure Docker Desktop is the active context:

```bash
docker context ls
docker context use desktop-linux
```

To upgrade Docker Desktop from a downloaded `.deb`:

```bash
systemctl --user stop docker-desktop
cd ~/Downloads
sudo apt-get update
sudo apt install ./docker-desktop-amd64.deb     # an "_apt sandbox" warning at the end can be ignored
systemctl --user start docker-desktop
```

## A2. Expected repository layout

```
gravisonde/
├── docker-compose.yml
├── sample_video.mp4                 # a real file (see A8)
├── scripts/local-up.sh              # optional helper (A11)
└── apps/
    ├── dashboard/
    │   ├── Dockerfile               # original in-Docker build (not used locally)
    │   ├── Dockerfile.local         # packages the host build (A6)
    │   ├── .dockerignore
    │   ├── next.config.ts           # must contain output: 'standalone'
    │   ├── package.json
    │   └── src/ ...
    └── cv-pipeline/
        ├── Dockerfile.local         # offline pip install (A5)
        ├── requirements.txt
        ├── wheels/                  # downloaded in A5, gitignored
        └── src/pipeline/main.py
```

## A3. Network preparation (only for slow or flaky connections)

Skip this section if downloads work normally.

**Host DNS: use Google only.** Cloudflare (`1.1.1.1`) was unreliable on the tested network.

```bash
sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
sudo sed -i 's|^DNS=.*|DNS=8.8.8.8 8.8.4.4|; s|^FallbackDNS=.*|FallbackDNS=|; s|^DNSOverTLS=.*|DNSOverTLS=no|' /etc/systemd/resolved.conf
sudo rm -f /etc/systemd/resolved.conf.d/dns.conf
sudo systemctl restart systemd-resolved

# Make programs use the caching local resolver
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
```

If the line `DNS=` does not exist in `/etc/systemd/resolved.conf`, add `DNS=8.8.8.8 8.8.4.4` under the `[Resolve]` heading by hand.

**Per-connection DNS** (replace the connection name with yours from `nmcli connection show`):

```bash
nmcli connection modify "YOUR-WIFI-NAME" ipv4.dns "8.8.8.8 8.8.4.4" ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes ipv6.dns ""
nmcli connection up "YOUR-WIFI-NAME"
```

**Docker Desktop DNS:** Settings → Docker Engine, add this key to the JSON, then Apply & restart:

```json
"dns": ["8.8.8.8", "8.8.4.4"]
```

**Verify:**

```bash
resolvectl status | head -12
for h in pypi.org files.pythonhosted.org registry.npmjs.org registry-1.docker.io; do
  getent hosts $h >/dev/null && echo "ok   $h" || echo "FAIL $h"
done
```

## A4. Pull the base images

```bash
docker pull --platform linux/amd64 node:22-alpine
docker pull --platform linux/amd64 python:3.11-slim
docker pull localstack/localstack:latest
docker images | grep -E "node|python|localstack"
```

Do not run `docker builder prune` or `docker system prune -a` afterwards. They delete the cache and images you just spent time downloading.

## A5. Pipeline image (OpenCV 5)

### 5.1 `apps/cv-pipeline/requirements.txt`

Known-good versions (the import test printed `5.0.0 1.19.2 2.4.6`). Make sure there are no stray shell commands in this file.

```
# OpenCV 5 pipeline
numpy==2.4.6
opencv-contrib-python-headless==5.0.0.93

# ONNX Runtime for the OpenCV DNN engine
onnxruntime==1.19.2

# CloudWatch / S3
boto3>=1.34.0,<1.36.0
botocore>=1.34.0,<1.36.0

# Utilities
python-dotenv==1.0.1
tqdm==4.66.5
requests==2.32.3

# Testing
pytest==8.3.4
pytest-mock==3.14.0
pytest-asyncio==0.23.7
```

### 5.2 Download the wheels on the host

This asks pip for **Python 3.11, Linux x86-64** wheels (matching the container, not your host Python). The loop retries on failure and keeps finished files.

```bash
cd apps/cv-pipeline
mkdir -p wheels

until pip download -r requirements.txt -d wheels \
  --only-binary=:all: --python-version 3.11 --implementation cp --abi cp311 \
  --platform manylinux_2_28_x86_64 --platform manylinux_2_27_x86_64 \
  --platform manylinux_2_17_x86_64 --platform manylinux2014_x86_64 \
  --platform manylinux_2_5_x86_64 --platform manylinux1_x86_64 \
  --timeout 120 --retries 10; do
  echo ">>> interrupted, retrying in 5s (finished files are kept)..."; sleep 5
done

ls wheels | wc -l       # about 31 files
du -sh wheels           # about 117 MB
for f in wheels/*.whl; do python3 -m zipfile -t "$f" >/dev/null 2>&1 || echo "BAD: $f"; done; echo "check done"
```

If a file is marked `BAD`, delete it and rerun the loop.

### 5.3 `apps/cv-pipeline/Dockerfile.local`

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN --mount=type=bind,source=wheels,target=/wheels \
    pip install --no-index --find-links=/wheels -r requirements.txt

COPY src/ ./src/

ENV PYTHONPATH=/app \
    PYTHONUNBUFFERED=1

CMD ["python", "-m", "src.pipeline.main"]
```

Make sure `apps/cv-pipeline/.dockerignore` does not list `wheels` or `*.whl`.

There is deliberately no `apt-get install ffmpeg`. On Debian it pulls 205 packages (133 MB), and the OpenCV wheel bundles its own video decoding. If your code runs the `ffmpeg` command itself, install it separately.

### 5.4 Build and test the image

```bash
cd ../..                                   # back to the repo root
docker compose --progress=plain build pipeline 2>&1 | tee build-pipeline.log

docker compose run --rm --no-deps pipeline \
  python -c "import cv2, onnxruntime, numpy; print(cv2.__version__, onnxruntime.__version__, numpy.__version__)"
```

Expected output: `5.0.0 1.19.2 2.4.6`. If you see a `libglib` error, add this line to `Dockerfile.local` right after `FROM`:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends libglib2.0-0 \
 && rm -rf /var/lib/apt/lists/*
```

### Fast-network alternative

If your connection is good, use a normal online install instead of wheels:

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --default-timeout=120 --retries 5 -r requirements.txt
COPY src/ ./src/
ENV PYTHONPATH=/app PYTHONUNBUFFERED=1
CMD ["python", "-m", "src.pipeline.main"]
```

## A6. Dashboard image (Next.js 16)

### 6.1 Make sure standalone output is on

```bash
cd apps/dashboard
grep -n "standalone" next.config.ts || echo ">>> MISSING"
```

If missing, add `output: 'standalone'` to your existing config, keeping your other options:

```ts
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  // ...your existing options stay here
};

export default nextConfig;
```

### 6.2 Install dependencies on the host

```bash
for i in 1 2 3 4 5 6 7 8 9 10; do
  npm ci --no-audit --no-fund --fetch-timeout=600000 --fetch-retries=5 && break
  echo ">>> attempt $i failed, retrying in 5s"; sleep 5
done
```

### 6.3 Build with webpack

`NEXT_PUBLIC_*` values are baked into the browser bundle **at build time**. Setting them only in `docker-compose.yml` does not change an already-built bundle, so set them here.

```bash
rm -rf .next

export NEXT_PUBLIC_AWS_REGION=us-east-1
export NEXT_PUBLIC_CW_LOG_GROUP=/aws/gravisonde/pipeline
export NEXT_PUBLIC_INSTANCE_TYPE=c8g.xlarge
export NEXT_PUBLIC_HOURLY_COST_USD=0.136
export NEXT_PUBLIC_S3_BUCKET=gravisonde-benchmarks-local
export NEXT_TELEMETRY_DISABLED=1

npx next build --webpack
mkdir -p public
find .next/standalone -maxdepth 4 -name server.js -not -path "*/node_modules/*"
```

The last command must print `.next/standalone/server.js`. A path nested deeper (for example `.next/standalone/apps/dashboard/server.js`) means the Dockerfile in 6.4 needs adjusting.

### 6.4 `apps/dashboard/Dockerfile.local` and `.dockerignore`

```bash
cat > Dockerfile.local <<'EOF'
# Local run: packages the build made on the host (no npm download inside Docker)
FROM node:22-alpine
WORKDIR /app

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0

COPY .next/standalone ./
COPY .next/static ./.next/static
COPY public ./public

EXPOSE 3000
CMD ["node", "server.js"]
EOF

cat > .dockerignore <<'EOF'
node_modules
.git
.env*
*.mp4
EOF
```

Do not add `.next` to `.dockerignore`. This Dockerfile needs it.

## A7. `docker-compose.yml`

Both services use `Dockerfile.local`. Place this at the repo root.

```yaml
# Gravisonde — Local Development Stack
# Spins up: Next.js dashboard, OpenCV pipeline (mock AWS), LocalStack
# No AWS credentials required for local development.
#
# Usage: http://localhost:3000

services:
  dashboard:
    build:
      context: ./apps/dashboard
      dockerfile: Dockerfile.local
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_AWS_REGION=us-east-1
      - NEXT_PUBLIC_CW_LOG_GROUP=/aws/gravisonde/pipeline
      - NEXT_PUBLIC_INSTANCE_TYPE=c8g.xlarge
      - NEXT_PUBLIC_HOURLY_COST_USD=0.136
      - NEXT_PUBLIC_S3_BUCKET=gravisonde-benchmarks-local
      - AWS_ENDPOINT_URL=http://localstack:4566
      - AWS_DEFAULT_REGION=us-east-1
      - AWS_ACCESS_KEY_ID=test
      - AWS_SECRET_ACCESS_KEY=test
    depends_on:
      - localstack
      - pipeline
    restart: unless-stopped

  pipeline:
    build:
      context: ./apps/cv-pipeline
      dockerfile: Dockerfile.local
    environment:
      - VIDEO_SOURCE=/data/sample.mp4
      - AWS_REGION=us-east-1
      - CW_LOG_GROUP=/aws/gravisonde/pipeline
      - S3_BENCHMARK_BUCKET=gravisonde-benchmarks-local
      - PIPELINE_MODE=cool
      - DETECTION_MODEL=yolo11n.onnx
      - CONF_THRESHOLD=0.5
      - METRICS_PUSH_INTERVAL_SEC=10
      - AWS_ENDPOINT_URL=http://localstack:4566
      - AWS_ACCESS_KEY_ID=test
      - AWS_SECRET_ACCESS_KEY=test
    volumes:
      - ./sample_video.mp4:/data/sample.mp4:ro
    depends_on:
      - localstack
    restart: unless-stopped

  localstack:
    image: localstack/localstack:latest
    ports:
      - "4566:4566"
    environment:
      - SERVICES=cloudwatch,s3,ec2,pricing
      - DEBUG=1
      - DOCKER_HOST=unix:///var/run/docker.sock
    volumes:
      - localstack_data:/var/lib/localstack
    restart: unless-stopped

volumes:
  localstack_data:
```

Validate it:

```bash
docker compose config -q && echo "compose OK"
```

## A8. Inputs the pipeline needs

```bash
ls -l sample_video.mp4
```

- `sample_video.mp4` must be a real **file**. If it is missing, Docker creates an empty *directory* in its place and the pipeline crashes confusingly.
- **[VERIFY]** `DETECTION_MODEL=yolo11n.onnx` must exist where `src/pipeline/main.py` looks for it (inside the image under `src/`, or mounted as a volume). Check how `main.py` resolves it.

## A9. Build, start, verify

Check that port 3000 is free:

```bash
ss -ltnp | grep ':3000' || echo "port 3000 is free"
```

Then:

```bash
docker compose --progress=plain build 2>&1 | tee build-all.log
docker compose up -d
docker compose ps
```

Verify:

```bash
curl -s localhost:4566/_localstack/health | head -c 300     # LocalStack services
curl -sI localhost:3000 | head -1                           # expect HTTP/1.1 200 OK
docker compose logs --tail=40 pipeline dashboard
```

Open **http://localhost:3000**.

## A10. Day-to-day commands

| Task | Commands |
|---|---|
| Changed dashboard code | Repeat 6.3 (webpack build), then `docker compose up -d --build dashboard` |
| Changed pipeline code | `docker compose up -d --build pipeline` |
| Changed pipeline dependencies | Redo 5.2 (wheels), then rebuild the pipeline |
| Follow logs | `docker compose logs -f pipeline` |
| Stop everything | `docker compose down` |
| Stop and wipe LocalStack data | `docker compose down -v` |
| Restart one service | `docker compose restart dashboard` |

## A11. Optional helper: `scripts/local-up.sh`

One command for the whole local flow after the first-time setup.

```bash
mkdir -p scripts
cat > scripts/local-up.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT/apps/dashboard"
export NEXT_PUBLIC_AWS_REGION=us-east-1
export NEXT_PUBLIC_CW_LOG_GROUP=/aws/gravisonde/pipeline
export NEXT_PUBLIC_INSTANCE_TYPE=c8g.xlarge
export NEXT_PUBLIC_HOURLY_COST_USD=0.136
export NEXT_PUBLIC_S3_BUCKET=gravisonde-benchmarks-local
export NEXT_TELEMETRY_DISABLED=1

[ -d node_modules ] || npm ci --no-audit --no-fund --fetch-timeout=600000 --fetch-retries=5
npx next build --webpack
mkdir -p public

cd "$ROOT"
docker compose --progress=plain up -d --build
docker compose ps
echo "Dashboard: http://localhost:3000"
EOF
chmod +x scripts/local-up.sh
```

Run it with `./scripts/local-up.sh`.

## A12. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `bad address` / `Could not resolve host` | DNS. Redo A3 and test with the `getent` loop. |
| Build stalls or times out on a download | The link is slow. Rerun the same command (finished layers are cached), or do the first build on a faster network. |
| `Turbopack build failed ... lightningcss` | Building with Turbopack. Always use `npx next build --webpack`. |
| Dashboard container exits with a `server.js` error | `output: 'standalone'` missing in `next.config.ts` (6.1), or `server.js` is nested deeper (6.3). |
| `invalid ELF header` or `sharp` errors at runtime | The host build carries glibc binaries and the image is Alpine (musl). Only matters if the app uses `next/image` optimization. Switch the runtime image to `node:22-slim` or disable image optimization. |
| `No matching distribution found` in the pipeline build | A wheel is missing. Redo 5.2 and check `ls wheels`. |
| `libglib` / `libGL` error on `import cv2` | Add the small `apt-get install libglib2.0-0` shown in 5.4. |
| Pipeline restarts in a loop | `docker compose logs pipeline`. Usually a missing `yolo11n.onnx`, or `sample_video.mp4` being an empty folder. |
| LocalStack exits immediately | `docker compose logs localstack`. Recent `latest` images may need an auth token. |
| Port 3000 already in use | `ss -ltnp \| grep :3000`, then stop that process. |
| Browser shows old values for `NEXT_PUBLIC_*` | They are baked in at build time. Rebuild with 6.3. |

---

# Part B: Deploy remotely (Vercel + AWS)

## B0. Architecture

```
  EC2 c8g.xlarge (arm64)                 AWS (us-east-1)                     Vercel
 ┌─────────────────────┐   writes   ┌─────────────────────────┐   reads   ┌────────────────┐
 │ pipeline container  │ ─────────▶ │ CloudWatch Logs (group) │ ◀──────── │ Next.js app     │
 │ OpenCV 5 + ONNX     │            │ S3 benchmark bucket     │           │ /api/metrics    │
 │ (IAM instance role) │ ─────────▶ │                         │ ◀──────── │ /api/benchmark  │
 └─────────────────────┘            └─────────────────────────┘           └────────────────┘
                                                                              ▲
                                                                              │ https://<project>.vercel.app
                                                                           Your browser
```

Key point: **Vercel cannot reach LocalStack.** `AWS_ENDPOINT_URL=http://localstack:4566` only exists inside your local Docker network. The deployed dashboard has to read the **real** CloudWatch and S3, and something has to write to them. That is the job of the pipeline running on EC2.

Your own config points at `c8g.xlarge`, which is a Graviton (**arm64**) instance. That matters for B4.

## B1. Accounts and tools you need

- GitHub account (the repo must be pushed there for the easiest Vercel flow)
- AWS account with permission to create S3, CloudWatch, IAM and EC2 resources
- Vercel account (Hobby is enough to start)
- AWS CLI on your laptop, configured with an admin or power-user profile:

```bash
aws --version
aws configure           # access key, secret, region us-east-1
aws sts get-caller-identity
```

## B2. Prepare the code for Vercel

### 2.1 Make the build use webpack

Vercel builds on Linux x64 and may hit the same Turbopack/Tailwind native-module error seen locally. In `apps/dashboard/package.json` change the build script:

```json
"scripts": {
  "build": "next build --webpack"
}
```

Leave your other scripts (`dev`, `start`, ...) as they are.

### 2.2 Keep standalone output for Docker only

Vercel does not need standalone output. Make it conditional so local Docker still works. **[VERIFY]** merge into your existing `next.config.ts`:

```ts
const nextConfig: NextConfig = {
  output: process.env.VERCEL ? undefined : "standalone",
  // ...your existing options
};
```

Vercel sets `VERCEL=1` during its builds.

### 2.3 AWS credentials: do not use the standard variable names on Vercel

Vercel's reserved-variables documentation lists `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_REGION`, `AWS_DEFAULT_REGION` and `AWS_SECRET_KEY` as unavailable for use (https://vercel.com/docs/environment-variables/reserved-environment-variables). Your local setup uses the standard names, so the deployed app needs **custom names** and must pass credentials to the AWS SDK explicitly.

**[VERIFY]** find where the dashboard creates its AWS clients (search for `CloudWatchLogsClient`, `S3Client`, `fromEnv`, `AWS_ENDPOINT_URL`):

```bash
grep -rn "Client(\|AWS_ENDPOINT_URL\|AWS_ACCESS_KEY_ID" apps/dashboard/src | head -20
```

Then add one shared config file, for example `apps/dashboard/src/lib/aws-config.ts`:

```ts
// Shared AWS client settings.
// Local (Docker + LocalStack): AWS_ENDPOINT_URL and the standard test credentials come from the environment.
// Vercel: reserved AWS_* names cannot be used, so custom GRAVI_* variables supply region and credentials.
const region =
  process.env.GRAVI_AWS_REGION ??
  process.env.AWS_REGION ??
  process.env.AWS_DEFAULT_REGION ??
  "us-east-1";

const accessKeyId = process.env.GRAVI_AWS_ACCESS_KEY_ID;
const secretAccessKey = process.env.GRAVI_AWS_SECRET_ACCESS_KEY;

export const awsClientConfig = {
  region,
  ...(process.env.AWS_ENDPOINT_URL ? { endpoint: process.env.AWS_ENDPOINT_URL } : {}),
  ...(accessKeyId && secretAccessKey
    ? { credentials: { accessKeyId, secretAccessKey } }
    : {}),
};
```

Use it where the clients are created, keeping any options you already pass (for example `forcePathStyle` for LocalStack's S3):

```ts
const logs = new CloudWatchLogsClient({ ...awsClientConfig });
const s3 = new S3Client({ ...awsClientConfig, forcePathStyle: !!process.env.AWS_ENDPOINT_URL });
```

If `GRAVI_*` are unset (local Docker), the SDK falls back to its normal credential chain, so the local stack keeps working.

### 2.4 `.gitignore` and push to GitHub

Make sure the repo root `.gitignore` contains:

```
node_modules
.next
.env*
!.env.example
wheels/
*.log
.backup/
*.bak
```

Then:

```bash
git add -A
git status --short | head -30          # confirm no secrets, wheels, .next or node_modules
git commit -m "Prepare for remote deployment"
git remote add origin git@github.com:<you>/gravisonde.git     # skip if it already exists
git push -u origin main
```

## B3. Create the AWS resources

Run from your laptop (AWS CLI configured):

```bash
export AWS_REGION=us-east-1
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export BUCKET=gravisonde-benchmarks-$ACCOUNT_ID       # bucket names are global, so the account ID keeps it unique
export LOG_GROUP=/aws/gravisonde/pipeline
echo "$ACCOUNT_ID $BUCKET"
```

### 3.1 S3 bucket and log group

```bash
aws s3api create-bucket --bucket "$BUCKET" --region "$AWS_REGION"
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws logs create-log-group --log-group-name "$LOG_GROUP" --region "$AWS_REGION"
aws logs put-retention-policy --log-group-name "$LOG_GROUP" --retention-in-days 14 --region "$AWS_REGION"
```

### 3.2 Read-only user for the dashboard (used by Vercel)

**[VERIFY]** This policy covers what a CloudWatch/S3/EC2/Pricing dashboard typically needs. Trim or extend it after checking which AWS calls your `/api/metrics` and `/api/benchmark` routes make.

```bash
cat > dashboard-read-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadPipelineLogs",
      "Effect": "Allow",
      "Action": ["logs:DescribeLogStreams", "logs:GetLogEvents", "logs:FilterLogEvents", "logs:StartQuery"],
      "Resource": [
        "arn:aws:logs:${AWS_REGION}:${ACCOUNT_ID}:log-group:${LOG_GROUP}",
        "arn:aws:logs:${AWS_REGION}:${ACCOUNT_ID}:log-group:${LOG_GROUP}:*"
      ]
    },
    {
      "Sid": "LogQueryResultsAndMetrics",
      "Effect": "Allow",
      "Action": ["logs:GetQueryResults", "logs:DescribeLogGroups", "cloudwatch:GetMetricData", "cloudwatch:ListMetrics"],
      "Resource": "*"
    },
    {
      "Sid": "ReadBenchmarkBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::${BUCKET}"
    },
    {
      "Sid": "ReadBenchmarkObjects",
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::${BUCKET}/*"
    },
    {
      "Sid": "InstanceAndPricingInfo",
      "Effect": "Allow",
      "Action": ["ec2:DescribeInstances", "ec2:DescribeInstanceTypes", "pricing:GetProducts"],
      "Resource": "*"
    }
  ]
}
EOF

aws iam create-policy --policy-name gravisonde-dashboard-read --policy-document file://dashboard-read-policy.json
aws iam create-user --user-name gravisonde-dashboard
aws iam attach-user-policy --user-name gravisonde-dashboard \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/gravisonde-dashboard-read
aws iam create-access-key --user-name gravisonde-dashboard
```

The last command prints the access key ID and the secret **once**. Copy them into a password manager now. They become `GRAVI_AWS_ACCESS_KEY_ID` and `GRAVI_AWS_SECRET_ACCESS_KEY` in B5. Never commit them.

### 3.3 Role for the pipeline instance (no keys on the server)

```bash
cat > ec2-trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Principal": { "Service": "ec2.amazonaws.com" }, "Action": "sts:AssumeRole" }
  ]
}
EOF

cat > pipeline-write-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "WritePipelineLogs",
      "Effect": "Allow",
      "Action": ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"],
      "Resource": [
        "arn:aws:logs:${AWS_REGION}:${ACCOUNT_ID}:log-group:${LOG_GROUP}",
        "arn:aws:logs:${AWS_REGION}:${ACCOUNT_ID}:log-group:${LOG_GROUP}:*"
      ]
    },
    {
      "Sid": "PutMetrics",
      "Effect": "Allow",
      "Action": ["cloudwatch:PutMetricData"],
      "Resource": "*"
    },
    {
      "Sid": "BenchmarkBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::${BUCKET}"
    },
    {
      "Sid": "BenchmarkObjects",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::${BUCKET}/*"
    }
  ]
}
EOF

aws iam create-role --role-name gravisonde-pipeline-role --assume-role-policy-document file://ec2-trust.json
aws iam put-role-policy --role-name gravisonde-pipeline-role \
  --policy-name gravisonde-pipeline-write --policy-document file://pipeline-write-policy.json
aws iam create-instance-profile --instance-profile-name gravisonde-pipeline-profile
aws iam add-role-to-instance-profile --instance-profile-name gravisonde-pipeline-profile \
  --role-name gravisonde-pipeline-role
```

Delete the local JSON files afterwards if you like (`rm *.json` in that folder). They contain no secrets.

## B4. Run the pipeline on AWS (EC2, arm64)

### 4.1 Why not reuse the local image

- `c8g.xlarge` is **arm64**. The `wheels/` folder holds x86-64 wheels, so `Dockerfile.local` will not work there.
- An EC2 instance has a fast connection, so a normal online `pip install` is fine.

Create `apps/cv-pipeline/Dockerfile` (the production one) and commit it:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --default-timeout=120 --retries 5 -r requirements.txt

COPY src/ ./src/

ENV PYTHONPATH=/app \
    PYTHONUNBUFFERED=1

CMD ["python", "-m", "src.pipeline.main"]
```

**[VERIFY]** this assumes aarch64 wheels exist for `opencv-contrib-python-headless==5.0.0.93` and `onnxruntime==1.19.2` on Python 3.11. If pip fails on the instance with "No matching distribution", paste the message and the pins can be adjusted.

### 4.2 Launch the instance

In the AWS console → EC2 → Launch instance (region us-east-1):

| Setting | Value |
|---|---|
| Name | `gravisonde-pipeline` |
| AMI | Amazon Linux 2023, **64-bit (Arm)** |
| Instance type | `c8g.xlarge` |
| Key pair | Create or choose one (for SSH) |
| Network / security group | Allow SSH (22) **only from your IP**. No other inbound rules are needed. |
| Storage | 30 GiB gp3 |
| Advanced details → IAM instance profile | `gravisonde-pipeline-profile` |

Containers need the instance role through the metadata service, which needs a hop limit of 2. After launch, run this from your laptop (replace the instance ID):

```bash
aws ec2 modify-instance-metadata-options --instance-id i-0123456789abcdef0 \
  --http-tokens required --http-put-response-hop-limit 2 --region us-east-1
```

### 4.3 Install Docker and run the pipeline

SSH in (`ssh -i your-key.pem ec2-user@<public-ip>`), then:

```bash
sudo dnf install -y docker git
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
exit            # log out and back in so the group applies
```

After reconnecting:

```bash
git clone https://github.com/<you>/gravisonde.git
cd gravisonde/apps/cv-pipeline
docker build -t gravisonde-pipeline .

mkdir -p ~/data
# Copy your sample video to ~/data/sample.mp4 (from your laptop: scp -i your-key.pem sample_video.mp4 ec2-user@<ip>:~/data/sample.mp4)
```

Run it. There is **no** `AWS_ENDPOINT_URL` and **no** access keys: it uses the instance role.

```bash
docker run -d --name gravisonde-pipeline --restart unless-stopped \
  -e AWS_REGION=us-east-1 \
  -e CW_LOG_GROUP=/aws/gravisonde/pipeline \
  -e S3_BENCHMARK_BUCKET=<your-bucket-name> \
  -e PIPELINE_MODE=cool \
  -e DETECTION_MODEL=yolo11n.onnx \
  -e CONF_THRESHOLD=0.5 \
  -e METRICS_PUSH_INTERVAL_SEC=10 \
  -e VIDEO_SOURCE=/data/sample.mp4 \
  -v /home/ec2-user/data:/data:ro \
  gravisonde-pipeline

docker logs --tail=50 -f gravisonde-pipeline
```

**[VERIFY]** the model file `yolo11n.onnx` must be inside the image or mounted, as in A8.

### 4.4 Confirm data is arriving in AWS

From your laptop:

```bash
aws logs describe-log-streams --log-group-name /aws/gravisonde/pipeline --region us-east-1 --max-items 3
aws logs tail /aws/gravisonde/pipeline --since 10m --region us-east-1
aws s3 ls s3://$BUCKET/ --recursive | head
```

You should see log streams and recent events. If not, check `docker logs gravisonde-pipeline` for `AccessDenied` (role or policy) or `NoCredentialsError` (hop limit not applied).

## B5. Deploy the dashboard on Vercel

### Option 1: Vercel dashboard (recommended)

1. Go to **vercel.com → Add New… → Project** and import the GitHub repository.
2. In **Configure Project**:
   - **Framework Preset:** Next.js (auto-detected)
   - **Root Directory:** click *Edit* and choose `apps/dashboard`
   - **Build Command:** leave the default (it runs `npm run build`, which now uses `--webpack`)
   - **Output Directory** and **Install Command:** leave the defaults
3. Open **Environment Variables** and add these for **Production** (and Preview if you want preview deployments to work):

| Name | Value | Notes |
|---|---|---|
| `NEXT_PUBLIC_AWS_REGION` | `us-east-1` | Public (sent to browsers) |
| `NEXT_PUBLIC_CW_LOG_GROUP` | `/aws/gravisonde/pipeline` | Public |
| `NEXT_PUBLIC_INSTANCE_TYPE` | `c8g.xlarge` | Public |
| `NEXT_PUBLIC_HOURLY_COST_USD` | `0.136` | Public |
| `NEXT_PUBLIC_S3_BUCKET` | your real bucket name | Public |
| `GRAVI_AWS_REGION` | `us-east-1` | Server only |
| `GRAVI_AWS_ACCESS_KEY_ID` | from step 3.2 | Mark **Sensitive** |
| `GRAVI_AWS_SECRET_ACCESS_KEY` | from step 3.2 | Mark **Sensitive** |

**Do not add:** `AWS_ENDPOINT_URL` (it would point at LocalStack), the test credentials (`test`/`test`), or `AWS_REGION`, `AWS_DEFAULT_REGION`, `AWS_SECRET_ACCESS_KEY` (reserved by Vercel).

4. Click **Deploy**. When it finishes, Vercel shows a URL like `https://<project>.vercel.app`.
5. Optional: **Settings → General → Node.js Version** → 22.x. **Settings → Functions → Function Region** → `iad1` (US East), which keeps API calls close to your us-east-1 AWS resources.

### Option 2: Vercel CLI

```bash
npm i -g vercel
cd apps/dashboard
vercel login
vercel link                      # create or link a project; accept ./ as the root since you are inside apps/dashboard

# Add each variable (the CLI prompts for the value)
vercel env add NEXT_PUBLIC_AWS_REGION production
vercel env add NEXT_PUBLIC_CW_LOG_GROUP production
vercel env add NEXT_PUBLIC_INSTANCE_TYPE production
vercel env add NEXT_PUBLIC_HOURLY_COST_USD production
vercel env add NEXT_PUBLIC_S3_BUCKET production
vercel env add GRAVI_AWS_REGION production
vercel env add GRAVI_AWS_ACCESS_KEY_ID production
vercel env add GRAVI_AWS_SECRET_ACCESS_KEY production --sensitive

vercel --prod
```

## B6. Verify the deployment

1. Open the Vercel URL. The page should render with live data from CloudWatch and S3.
2. Test the API routes directly (they are server-rendered on demand):

```bash
curl -s https://<project>.vercel.app/api/metrics | head -c 400
curl -s https://<project>.vercel.app/api/benchmark | head -c 400
```

3. If a route returns an error, open **Vercel → your project → Deployments → (latest) → Logs** and read the function error:

| Error | Likely cause |
|---|---|
| `AccessDenied` / `not authorized to perform` | Missing action in `gravisonde-dashboard-read`. Add the action named in the message. |
| `CredentialsProviderError` / `Missing credentials` | `GRAVI_AWS_*` not set for this environment, or the code from 2.3 is not using `awsClientConfig`. |
| `ResourceNotFoundException` (log group) | Wrong `NEXT_PUBLIC_CW_LOG_GROUP`, or wrong region. |
| `NoSuchBucket` | Wrong `NEXT_PUBLIC_S3_BUCKET`. |
| Empty charts, no errors | The pipeline is not writing yet. Redo B4.4. |
| Build error mentioning `lightningcss` | `package.json` build script is not `next build --webpack` (2.1). |

4. Changing any `NEXT_PUBLIC_*` value needs a **redeploy** (Deployments → ⋯ → Redeploy), because those values are baked into the build.

## B7. Update workflow

| Change | Do this |
|---|---|
| Dashboard code | `git push` to the connected branch. Vercel redeploys automatically (production for `main`, previews for other branches). |
| Env var | Edit it in Vercel, then redeploy. |
| Pipeline code | SSH to the instance: `cd gravisonde && git pull && cd apps/cv-pipeline && docker build -t gravisonde-pipeline . && docker rm -f gravisonde-pipeline`, then rerun the `docker run` command from 4.3. |
| Rotate dashboard keys | `aws iam create-access-key --user-name gravisonde-dashboard`, update the two Vercel variables, redeploy, then `aws iam delete-access-key` for the old key. |

## B8. Security and cost checklist

- [ ] No secrets in git (`git log -p | grep -i "secret"` should find nothing real).
- [ ] Dashboard IAM user is **read-only** and limited to the log group, bucket and describe/pricing calls.
- [ ] Pipeline uses an instance **role**, with no keys on the server.
- [ ] S3 bucket has public access blocked (done in 3.1).
- [ ] EC2 security group allows SSH only from your IP (or use AWS Systems Manager Session Manager and close port 22).
- [ ] `GRAVI_AWS_SECRET_ACCESS_KEY` is marked Sensitive in Vercel.
- [ ] The dashboard has no login. Anyone with the URL sees your metrics. For a private demo, turn on Vercel Deployment Protection (Settings → Deployment Protection) or add authentication.
- [ ] Cost: your own config assumes `0.136` USD per hour for the instance, about 98 USD for a 30-day month if it runs continuously. Stop it when idle: `aws ec2 stop-instances --instance-ids i-... --region us-east-1`.

**Teardown** (to stop all charges):

```bash
aws ec2 terminate-instances --instance-ids i-0123456789abcdef0 --region us-east-1
aws s3 rb s3://$BUCKET --force
aws logs delete-log-group --log-group-name /aws/gravisonde/pipeline --region us-east-1
aws iam detach-user-policy --user-name gravisonde-dashboard --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/gravisonde-dashboard-read
aws iam delete-access-key --user-name gravisonde-dashboard --access-key-id <KEY_ID>
aws iam delete-user --user-name gravisonde-dashboard
aws iam delete-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/gravisonde-dashboard-read
aws iam remove-role-from-instance-profile --instance-profile-name gravisonde-pipeline-profile --role-name gravisonde-pipeline-role
aws iam delete-instance-profile --instance-profile-name gravisonde-pipeline-profile
aws iam delete-role-policy --role-name gravisonde-pipeline-role --policy-name gravisonde-pipeline-write
aws iam delete-role --role-name gravisonde-pipeline-role
```

Then delete the project in Vercel (Settings → Advanced → Delete Project).

## B9. Open items to confirm

These depend on files not yet reviewed:

1. **Dashboard AWS client code** (2.3): where the clients are created, so credentials can be passed explicitly. Also which AWS actions the two API routes call, so the IAM policy in 3.2 can be tightened.
2. **`src/pipeline/main.py`**: where `yolo11n.onnx` is loaded from, how `VIDEO_SOURCE` is read (local file vs S3), and whether anything runs the `ffmpeg` command.
3. **`next.config.ts`**: the exact contents, to merge the conditional `output` setting safely.
4. **arm64 wheels** (4.1): that OpenCV 5.0.0.93 and onnxruntime 1.19.2 install on Graviton. The instance build will confirm.
