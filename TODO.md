# Gravisonde — Post-Test Todo

Status after the build-fix session: all code bugs fixed, environment noted. Network blocks prevent local `npm install` / `pip install` / typecheck verification in the sandbox — those must run on your machine after you boot back up.

## Immediate (do right when you boot back up)

- [ ] Run `cd apps/dashboard && npm install && npm run typecheck && npm run build` — verify Next.js 16 dashboard compiles
- [ ] Run `cd apps/cv-pipeline && pip install -r requirements.txt && python -c "import cv2; print(cv2.__version__)"` — verify OpenCV pipeline deps resolve
- [ ] Run `make local-up` — verify dashboard + stub pipeline + LocalStack come up at localhost:3000

## Remaining deliverables (in priority order)

- [x] **`docs/technical-report.mdx`** — exists as `docs/technical-report.md` (6.3 KB). Content drafted in `src/app/report/page.tsx`. Ready to rename to `.mdx` if needed.
- [x] **`docs/architecture.mmd`** — exists (1.6 KB), created from docs/architecture.md
- [x] **`docs/reproduction-guide.md`** — exists (3.6 KB)
- [x] **`docs/demo-script.md`** — exists (3.0 KB)

## Optional polish

- [x] Generate a real `sample_video.mp4` at repo root — file exists (3.4 MB)
- [x] `git init && git add -A && git commit` — repo has 10 commits
- [ ] `make benchmark` — COOL vs stock fps-per-dollar comparison on c8g.xlarge vs c7i.xlarge (needs AWS deployment)

## Known constraints to record

- Sandbox blocks `registry.npmjs.org` and `pypi.org` — cannot verify builds from this session
- `boto3>=1.34.0,<1.36.0` and `botocore>=1.34.0,<1.36.0` loosened for Python 3.10 compatibility in `apps/cv-pipeline/requirements.txt`


Final reminder
Final Submission Package
    • A technical report describing the problem, users, architecture, OpenCV 5 implementation, AWS deployment, evaluation, limitations, and responsible-use considerations.

    • A public or private judge-accessible code repository or archive. The code does not have to be open source.

    • Pinned dependencies plus clear build, deployment, and test instructions.

    • An architecture diagram showing the OpenCV 5 and AWS components and, where relevant, COOL or agent components.

    • A working web endpoint or an arranged live screen-share demonstration.

    • A public or unlisted judge-accessible video of no more than five minutes that shows the team, the application working, its architecture, and its principal results.

    • Evaluation evidence appropriate to the project, including failure cases or limitations.

Additional Evidence for the Best Use of COOL Award
    • The COOL version and AWS instance or deployment configuration.

    • A reproducible evaluation method, inputs, baselines, and results.

    • Evidence that COOL executes the claimed core workload.

Additional Evidence for the Agentic Vision Award
    • An agent workflow diagram showing perception, decision or orchestration, and action.

    • A trace or demonstration showing that OpenCV 5 output changes a later decision, tool call, or action.

    • Evaluation of task success, failure handling, observability, and appropriate human con