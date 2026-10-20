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

## Build-Fix Session (2026-10-20) — defects found and fixed

### Root-cause analysis
A full code review of the existing codebase found 8 concrete defects that would have prevented
the project from running or from producing usable evidence. Each was fixed at its actual cause
per master_prompt Phase Six ("Fix errors based on their actual causes rather than introducing
unrelated changes").

### Defects fixed
1. **`scripts/bench_runner.py:18`** — imported `from pipeline import run_pipeline, init_collector`
   but `run_pipeline` lives in `apps/cv-pipeline/src/main.py`, not the `pipeline` package.
   Fixed to `from main import run_pipeline, init_collector` (path already on sys.path).
2. **`apps/cv-pipeline/src/main.py`** — `if __name__ == "__main__": main()` appeared
   *before* `def main()`, raising `NameError` on every invocation. Removed the premature call;
   the correct one after `def main()` was kept.
3. **`apps/cv-pipeline/src/pipeline/capture.py`** — `_create_test_pattern_capture` used
   `np.zeros` / `cv2.putText` but `numpy` was never imported at module level. Added
   `import numpy as np`.
4. **`apps/cv-pipeline/src/pipeline/detection.py`** — dummy-net path returned `[]` for every
   frame (empty `cv2.dnn.Net()` yields `getLayerNames() == []`, which is falsy). Replaced with
   `_synthetic_detections()` that derives a real detection count from **OpenCV 5 contour analysis**
   of the actual frame (Canny → morphological close → findContours → bounding boxes), and added
   `Detector.mode` ("onnx" vs "synthetic") so callers can never present synthetic output as model
   output. Counts are bounded to 12.
5. **`apps/cv-pipeline/src/main.py`** — `inference_ms = t1 - t0 if frame_id == 0 else 0` measured
   frame-0 read time and returned 0 for every subsequent frame. Fixed to `inference_ms = (t2 - t1) * 1000`
   (detection + feature extraction time), matching the `latency_ms` measurement.
6. **`apps/cv-pipeline/Dockerfile.local`** — `CMD ["python", "-m", "pipeline.main"]` but the module
   lives at `/app/src/pipeline/main.py`. Fixed to `python -m src.pipeline.main`.
7. **`apps/cv-pipeline/src/__init__.py`** — `from .main import run_pipeline` referenced a
   non-existent `src/main.py`. Fixed to `from .pipeline.main import main, run_pipeline`.
8. **Contract bug (critical)** — pipeline emitted **snake_case** JSON (`frame_id`, `latency_ms`,
   `inference_ms`, `instance_id`, `opencv_version`, `cool_version`) but the dashboard's Zod
   `FrameMetricSchema` expected **camelCase** (`frameId`, `latencyMs`, `inferenceMs`,
   `instanceId`, `opencvVersion`, `coolVersion`). Every POST was rejected by Zod and the dashboard
   never received data. Fixed `FrameMetric.to_dict()` to emit camelCase via a `_to_camel` helper
   (applied to both `FrameMetric` and `BenchmarkRun` so the S3 JSON contract matches too).
9. **`apps/dashboard/src/app/api/metrics/route.ts`** — SSE stream emitted a bare metrics object
   but `sse.ts` parses `{type, data}` via `SSEEventSchema`, so the dashboard received nothing.
   Wrapped every SSE payload as `{ type: "metrics", data: aggregated }`.
10. **`apps/dashboard/src/components/MetricsCharts.tsx`** — FPS chart rendered both an `Area`
    and a `Line` over the same `fps` data key, duplicating the FPS series. Removed the duplicate
    `Line`.
11. **`apps/dashboard/src/components/BenchmarkDownload.tsx`** — appended a broken
    `declare global { interface URL { blobURL?(...) } }` + `URL.blobURL = ...` that polluted the
    global `URL` type and would fail typecheck. Removed; the component already calls
    `URL.revokeObjectURL` correctly.

### Decisions
1. **Synthetic detections are derived, not random.** When no ONNX model is present (local dev / CI),
   the pipeline still produces non-zero metrics by running real OpenCV 5 contour analysis on the
   actual frame. This keeps the pipeline honest and runnable without a model download, while
   `Detector.mode` makes the distinction visible to judges.
2. **Single source of truth for field naming.** The dashboard's Zod schemas define the contract;
   the Python side now conforms to it. This avoids a second drift bug.
3. **`.claude/` added to `.gitignore`.** The repo's `.claude/` directory holds local editor
   configuration and is not part of the submission.
4. **First commit created** (root commit `a4a8c6d`) with all fixes. Repo now has a clean history.
