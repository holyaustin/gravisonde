# Gravisonde — Makefile
# Usage: make <target>
# Key targets: local-up, bootstrap, deploy-infra, build-pipeline, deploy-dashboard, start-pipeline, benchmark

.PHONY: help local-up local-down bootstrap deploy-infra destroy-infra \
        build-pipeline build-dashboard deploy-dashboard start-pipeline \
        benchmark clean test lint typecheck

# Default target
help:
	@echo "Gravisonde — Make targets:"
	@echo ""
	@echo "  Local Development:"
	@echo "    local-up        Start local stack (dashboard + pipeline + localstack)"
	@echo "    local-down      Stop local stack"
	@echo ""
	@echo "  AWS Infrastructure:"
	@echo "    bootstrap       CDK bootstrap (run once per account/region)"
	@echo "    deploy-infra    Deploy EC2, S3, CloudWatch, ALB via CDK"
	@echo "    destroy-infra   Destroy all AWS resources"
	@echo ""
	@echo "  Pipeline (OpenCV 5 on EC2):"
	@echo "    build-pipeline  Build Docker images (cool + stock)"
	@echo "    start-pipeline  Launch pipeline container on EC2 via SSM"
	@echo ""
	@echo "  Dashboard (Next.js 16):"
	@echo "    build-dashboard Build Next.js production bundle"
	@echo "    deploy-dashboard Deploy to Vercel (or ALB if configured)"
	@echo ""
	@echo "  Benchmarking:"
	@echo "    benchmark       Run COOL vs stock comparison, upload CSV to S3"
	@echo ""
	@echo "  Quality:"
	@echo "    test            Run all tests (Python + TypeScript)"
	@echo "    lint            Run linters"
	@echo "    typecheck       TypeScript type checking"
	@echo ""
	@echo "  Utility:"
	@echo "    clean           Remove build artifacts"

# =============================================================================
# Local Development
# =============================================================================
local-up:
	docker compose up --build -d
	@echo ""
	@echo "Local stack running:"
	@echo "  Dashboard:  http://localhost:3000"
	@echo "  LocalStack: http://localhost:4566"
	@echo "  Pipeline logs: docker compose logs -f pipeline"

local-down:
	docker compose down -v

# =============================================================================
# AWS Infrastructure (CDK)
# =============================================================================
bootstrap:
	cd infra && npx cdk bootstrap

deploy-infra:
	cd infra && npx cdk deploy --require-approval never

destroy-infra:
	cd infra && npx cdk destroy --force

# =============================================================================
# Pipeline Docker Images
# =============================================================================
build-pipeline:
	docker build -f apps/cv-pipeline/Dockerfile.cool -t gravisonde-pipeline:cool apps/cv-pipeline
	docker build -f apps/cv-pipeline/Dockerfile.stock -t gravisonde-pipeline:stock apps/cv-pipeline

# Push to ECR (requires ECR repo created by CDK)
push-pipeline:
	aws ecr get-login-password --region $$(aws configure get region) | docker login --username AWS --password-stdin $$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$$(aws configure get region).amazonaws.com
	docker tag gravisonde-pipeline:cool $$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$$(aws configure get region).amazonaws.com/gravisonde-pipeline:cool
	docker tag gravisonde-pipeline:stock $$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$$(aws configure get region).amazonaws.com/gravisonde-pipeline:stock
	docker push $$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$$(aws configure get region).amazonaws.com/gravisonde-pipeline:cool
	docker push $$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$$(aws configure get region).amazonaws.com/gravisonde-pipeline:stock

# =============================================================================
# Dashboard (Next.js 16)
# =============================================================================
build-dashboard:
	cd apps/dashboard && npm run build

deploy-dashboard:
	# Assumes Vercel CLI installed and linked to project
	cd apps/dashboard && vercel --prod

# =============================================================================
# Pipeline Execution on EC2
# =============================================================================
start-pipeline:
	@echo "Starting pipeline on EC2 via SSM..."
	@INSTANCE_ID=$$(aws ec2 describe-instances \
		--filters "Name=tag:Name,Values=gravisonde-pipeline" "Name=instance-state-name,Values=running" \
		--query "Reservations[0].Instances[0].InstanceId" --output text); \
	if [ "$$INSTANCE_ID" = "None" ] || [ -z "$$INSTANCE_ID" ]; then \
		echo "No running gravisonde-pipeline instance found. Deploy infra first."; \
		exit 1; \
	fi; \
	aws ssm send-command \
		--instance-ids "$$INSTANCE_ID" \
		--document-name "AWS-RunShellScript" \
		--parameters 'commands=["cd /opt/gravisonde && docker compose -f docker-compose.ec2.yml up -d"]' \
		--comment "Start Gravisonde pipeline"

# =============================================================================
# Benchmarking
# =============================================================================
benchmark:
	@echo "Running benchmark on EC2 (sequential: cool then stock)..."
	@INSTANCE_ID=$$(aws ec2 describe-instances \
		--filters "Name=tag:Name,Values=gravisonde-pipeline" "Name=instance-state-name,Values=running" \
		--query "Reservations[0].Instances[0].InstanceId" --output text); \
	if [ "$$INSTANCE_ID" = "None" ] || [ -z "$$INSTANCE_ID" ]; then \
		echo "No running instance found."; exit 1; \
	fi; \
	echo "Running COOL pipeline benchmark (300s)..."; \
	aws ssm send-command --instance-ids "$$INSTANCE_ID" --document-name "AWS-RunShellScript" \
		--parameters 'commands=["cd /opt/gravisonde && python -m bench.runner --duration 300 --pipeline cool --output /tmp/bench_cool.csv"]'; \
	sleep 320; \
	echo "Running STOCK pipeline benchmark (300s)..."; \
	aws ssm send-command --instance-ids "$$INSTANCE_ID" --document-name "AWS-RunShellScript" \
		--parameters 'commands=["cd /opt/gravisonde && python -m bench.runner --duration 300 --pipeline stock --output /tmp/bench_stock.csv"]'; \
	sleep 320; \
	echo "Generating comparison report..."; \
	aws ssm send-command --instance-ids "$$INSTANCE_ID" --document-name "AWS-RunShellScript" \
		--parameters 'commands=["cd /opt/gravisonde && python -m bench.compare --cool /tmp/bench_cool.csv --stock /tmp/bench_stock.csv --output /tmp/bench_report.json && aws s3 cp /tmp/bench_report.json s3://$$(aws cloudformation describe-stacks --stack-name GravisondeStack --query Stacks[0].Outputs[?OutputKey==BenchmarkBucketName].OutputValue --output text)/bench_report_$$(date +%s).json"]'; \
	echo "Benchmark complete. Check S3 bucket for results."

# =============================================================================
# Quality Gates
# =============================================================================
test:
	cd apps/cv-pipeline && python -m pytest tests/ -v
	cd apps/dashboard && npm test

lint:
	cd apps/cv-pipeline && python -m ruff check src/
	cd apps/dashboard && npm run lint

typecheck:
	cd apps/dashboard && npm run typecheck
	cd infra && npx tsc --noEmit

# =============================================================================
# Cleanup
# =============================================================================
clean:
	rm -rf apps/dashboard/.next apps/dashboard/node_modules
	rm -rf infra/node_modules infra/cdk.out
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name .pytest_cache -exec rm -rf {} + 2>/dev/null || true
	docker compose down -v 2>/dev/null || true