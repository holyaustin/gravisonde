# Gravisonde — Session Log

## Project
Gravisonde: Live performance benchmark of OpenCV 5 + COOL on AWS Graviton (c8g.xlarge)
vs stock OpenCV on x86 (c7i.xlarge). Targets the **COOL Award** ($1,000) in the
OpenCV AI Competition 2026.

## Current State (as of build fix session)

### Completed
1. Fixed typo `setDownlying` -> `setDownloading` in `BenchmarkDownload.tsx`
2. Added `src/main.py` — pipeline entrypoint (`run_pipeline`, `main`)
3. Added `scripts/bench_runner.py` — COOL vs stock CSV comparison runner
4. Added `scripts/stub_api.py` — local AWS service emulator for dev
5. Added Dockerfiles: `apps/dashboard/Dockerfile`, `apps/cv-pipeline/Dockerfile.{local,cool}`
6. Added `apps/dashboard/postcss.config.mjs`, `next-env.d.ts`
7. Fixed `next.config.ts` (removed `experimental.cacheComponents` — moved to stable in Next 15+)
8. Built `infra/` CDK stack: VPC, EC2 c8g.xlarge, IAM role/profile, S3 bucket, CloudWatch log group, security group, outputs
9. Added `.env.example`, `.gitignore`
10. Exported public API through all `__init__.py` files
11. Fixed `requirements.txt` to use version range `boto3>=1.34.0,<1.36.0` for Python 3.10 compatibility

### Missing Files (to create)
- `docs/images/banner.svg` (or update README to use existing public/ images)
- `docs/images/result-card.svg`
- `sample_video.mp4` — currently 0 bytes; `docker-compose.yml` mounts it read-only into `/data/sample.mp4`
- `git init && git add -A && git commit` — repo has no commits yet

### Environment Constraints
- **sandbox**: no network access to npm registry or PyPI. Cannot run `npm install`, `pip install`, `tsc`, or `next build` from inside the sandbox. User must run these locally.
- **Python**: Local environment has Python 3.10.12. `opencv-contrib-python-headless==5.0.0.93` resolves but boto3/botocore pins may need loosening (done). Docker images use Python 3.11/3.12.

### Commands
```bash
# Local dev (Docker Compose — dashboard + stub pipeline + LocalStack)
make local-up  # -> http://localhost:3000

# AWS
make bootstrap     # CDK bootstrap (once per account/region)
make deploy-infra  # EC2, S3, CloudWatch, ALB
make build-pipeline  # Docker images (cool + stock)
make start-pipeline  # SSM to EC2
make benchmark       # COOL vs stock comparison, upload CSV to S3

# Verify
cd apps/dashboard && npm install && npm run typecheck && npm run build
cd apps/cv-pipeline && pip install -r requirements.txt && python -c "import cv2; print(cv2.__version__)"
```

## Decisions
1. **Repo structure**: monorepo with `apps/{dashboard,cv-pipeline}` + `infra/` + `scripts/` + `docs/`. Matches README.
2. **Python 3.11 in Docker**: `Dockerfile.local` and `Dockerfile.cool` use `python:3.11-slim` / `ubuntu:24.04`. The COOL AMI ships its own Python — the Docker layers assume `/opt/cool` exists at runtime.
3. **boto3 version range**: loosened from exact pins to `>=1.34.0,<1.36.0` to allow pip to resolve compatible patches on Python 3.10.
4. **CDK approach**: single `GravisondeStack` with optional `CoolAmiId` parameter (CFN parameter for the Marketplace AMI ID). Outputs instance ID, public IP, bucket name, log group.
