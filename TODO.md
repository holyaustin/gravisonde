# Gravisonde — Post-Test Todo

Status after the build-fix session: all code bugs fixed, environment noted. Network blocks prevent local `npm install` / `pip install` / typecheck verification in the sandbox — those must run on your machine after you boot back up.

## Immediate (do right when you boot back up)

- [ ] Run `cd apps/dashboard && npm install && npm run typecheck && npm run build` — verify Next.js 16 dashboard compiles
- [ ] Run `cd apps/cv-pipeline && pip install -r requirements.txt && python -c "import cv2; print(cv2.__version__)"` — verify OpenCV pipeline deps resolve
- [ ] Run `make local-up` — verify dashboard + stub pipeline + LocalStack come up at localhost:3000

## Remaining deliverables (in priority order)

- [ ] **`docs/technical-report.mdx`** — competition entry write-up (problem, solution, differentiation, OpenCV 5 + AWS Graviton rationale, user journey, MVP table, stretch features, architecture, evidence/limitations, responsible use). Content already drafted in `src/app/report/page.tsx` — port/adapt into MDX.
- [ ] **`docs/architecture.mmd`** — Mermaid diagram of the architecture (VPC, EC2 c8g.xlarge, IAM, S3, CloudWatch, ALB, pipeline, dashboard)
- [ ] **`docs/reproduction-guide.md`** — step-by-step local dev + AWS deployment repro steps from `README.md` quick-start and CDK flow
- [ ] **`docs/demo-script.md`** — demo walkthrough for the competition judges (what to click, what metrics to watch, COOL vs stock comparison narrative)

## Optional polish

- [ ] Generate a real `sample_video.mp4` at repo root (current file is 0 bytes; `docker-compose.yml` mounts it read-only into `/data/sample.mp4`)
- [ ] `git init && git add -A && git commit` — repo currently has no commits
- [ ] `make benchmark` — COOL vs stock fps-per-dollar comparison on c8g.xlarge vs c7i.xlarge (needs AWS deployment)

## Known constraints to record

- Sandbox blocks `registry.npmjs.org` and `pypi.org` — cannot verify builds from this session
- `boto3>=1.34.0,<1.36.0` and `botocore>=1.34.0,<1.36.0` loosened for Python 3.10 compatibility in `apps/cv-pipeline/requirements.txt`
