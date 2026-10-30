git remote set-url origin git@github.com:holyaustin/gravisonde.git
Successfully initiated launch of instance (i-0b0b534bf1c3e6d97)
ssh -i ~/.ssh/gravisonde-aws-key ec2-user@16.16.75.56

docker build -t gravisonde-pipeline .
docker run -d --name gravisonde-pipeline --restart unless-stopped \
  -e AWS_REGION=eu-north-1 \
  -e CW_LOG_GROUP=/aws/gravisonde/pipeline \
  -e S3_BENCHMARK_BUCKET=gravisonde \
  -e PIPELINE_MODE=cool \
  -e DETECTION_MODEL=yolo11n.onnx \
  -e CONF_THRESHOLD=0.5 \
  -e METRICS_PUSH_INTERVAL_SEC=10 \
  -e VIDEO_SOURCE=/data/sample1.mp4 \
  -v /home/ec2-user/data:/data:ro \
  gravisonde-pipeline

docker logs -f gravisonde-pipeline
