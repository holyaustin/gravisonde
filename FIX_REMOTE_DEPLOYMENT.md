# Fix for Remote EC2 Deployment Issues

**Date:** 2026-11-01  
**Issues Fixed:**
1. YOLO11n model file not found in container
2. CloudWatch Metrics access denied (AWS SCP blocking)
3. Dashboard not receiving metrics remotely

## Root Causes

### Issue 1: Model File Not Found
The container searches for `yolo11n.onnx` in these directories:
- `/apps/cv-pipeline`
- `/app`
- `/`
- Current working directory

But the volume mount only placed it at `/home/ec2-user/gravisonde/data/yolo11n.onnx` on the host.

### Issue 2: CloudWatch Metrics Blocked
```
AccessDenied when calling PutMetricData: User is not authorized to perform: cloudwatch:PutMetricData 
with an explicit deny in a service control policy
```
This is an AWS Organization-level Service Control Policy (SCP) blocking CloudWatch Metrics API calls.

### Issue 3: Dashboard Metrics Not Showing
The metrics.py code already handles CloudWatch failures gracefully but the dashboard needs an alternative path to receive metrics.

## Solution

### Step 1: Fix Model File Path
Mount the model directly into the container's expected search paths:

```bash
# Download the model to the data directory (already done)
wget -O /home/ec2-user/gravisonde/data/yolo11n.onnx \
  "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.onnx"

# Mount it into multiple locations the container searches
docker run -d --name gravisonde-pipeline --restart unless-stopped \
  -e AWS_REGION=eu-north-1 \
  -e CW_LOG_GROUP=/aws/gravisonde/pipeline \
  -e S3_BENCHMARK_BUCKET=gravisonde \
  -e PIPELINE_MODE=cool \
  -e DETECTION_MODEL=yolo11n.onnx \
  -e CONF_THRESHOLD=0.5 \
  -e METRICS_PUSH_INTERVAL_SEC=10 \
  -v /home/ec2-user/gravisonde/data/sample.mp4:/data/sample.mp4:ro \
  -v /home/ec2-user/gravisonde/data/yolo11n.onnx:/app/yolo11n.onnx:ro \
  gravisonde-pipeline
```

### Step 2: Disable CloudWatch Metrics (Keep Logs)
The code already handles this gracefully. After the first AccessDenied error, it sets `self._cw_metrics = None` and stops retrying CloudWatch Metrics. CloudWatch Logs should still work if the IAM role has `logs:*` permissions.

### Step 3: Enable CloudWatch Logs for Dashboard
Update the dashboard to read metrics from CloudWatch Logs instead of CloudWatch Metrics.

The metrics are already being pushed to CloudWatch Logs at:
- Log Group: `/aws/gravisonde/pipeline`
- Log Stream: `{instance-id}-{date}`
- Format: JSON with camelCase fields

## Complete Deployment Commands

### On EC2 Instance (SSH)

```bash
# 1. Ensure model file exists
ls -lh /home/ec2-user/gravisonde/data/yolo11n.onnx
# Should show: ~10.4MB file

# 2. Stop existing container
docker rm -f gravisonde-pipeline

# 3. Run with corrected volume mounts
docker run -d --name gravisonde-pipeline --restart unless-stopped \
  -e AWS_REGION=eu-north-1 \
  -e AWS_DEFAULT_REGION=eu-north-1 \
  -e CW_LOG_GROUP=/aws/gravisonde/pipeline \
  -e S3_BENCHMARK_BUCKET=gravisonde \
  -e PIPELINE_MODE=cool \
  -e DETECTION_MODEL=yolo11n.onnx \
  -e CONF_THRESHOLD=0.5 \
  -e METRICS_PUSH_INTERVAL_SEC=10 \
  -v /home/ec2-user/gravisonde/data/sample.mp4:/data/sample.mp4:ro \
  -v /home/ec2-user/gravisonde/data/yolo11n.onnx:/app/yolo11n.onnx:ro \
  gravisonde-pipeline

# 4. Verify container started
docker ps | grep gravisonde-pipeline

# 5. Check logs for successful model loading
docker logs gravisonde-pipeline 2>&1 | head -20
```

### Expected Output (Success)
```
2026-11-01 15:20:00,123 INFO __main__: Starting Gravisonde pipeline: cool on graviton (c8g.xlarge)
2026-11-01 15:20:00,123 INFO __main__: Video source: /data/sample.mp4
2026-11-01 15:20:00,123 INFO __main__: OpenCV 5.0.0.93, COOL: N/A
2026-11-01 15:20:00,124 INFO src.pipeline.metrics: Metrics emitter started
2026-11-01 15:20:00,124 INFO src.pipeline.capture: Connecting to video source: /data/sample.mp4
2026-11-01 15:20:00,200 INFO src.pipeline.capture: Connected to /data/sample.mp4 (640x480@30fps)
2026-11-01 15:20:00,201 INFO src.pipeline.detection: Detector initialized: DNN=yolo11n.onnx, Feature=aliked
2026-11-01 15:20:10,300 WARNING src.pipeline.metrics: CloudWatch Metrics permanently disabled (SCP deny): ...
```

Key success indicators:
- ✅ `Detector initialized: DNN=yolo11n.onnx` (not "Model file ... not found")
- ✅ No "Using dummy detector" warning
- ✅ CloudWatch Metrics warning appears once then stops (graceful degradation)

## Verification Commands

```bash
# Watch live logs
docker logs -f gravisonde-pipeline

# Check metrics are being collected (should show frame processing)
docker exec gravisonde-pipeline ps aux | grep python

# Verify CloudWatch Logs are receiving data
aws logs tail /aws/gravisonde/pipeline --follow --region eu-north-1

# Check if real detections are being made (look for detection counts > 0)
docker logs gravisonde-pipeline 2>&1 | grep -i "detection"
```

## Dashboard Access

The dashboard needs to be updated to read from CloudWatch Logs since CloudWatch Metrics are blocked.

**Option A: Dashboard reads from CloudWatch Logs**
- Modify `apps/dashboard/src/app/api/metrics/route.ts` to query CloudWatch Logs
- Parse JSON log events to extract metrics

**Option B: Local HTTP endpoint** (for testing)
- Run dashboard locally: `cd apps/dashboard && npm run dev`
- Update pipeline to push to local endpoint:
  ```bash
  -e DASHBOARD_ENDPOINT=http://YOUR_LOCAL_IP:3000/api/metrics
  ```

## Testing the Fix

```bash
# 1. Stop and remove old container
docker rm -f gravisonde-pipeline

# 2. Re-run with correct mount
docker run -d --name gravisonde-pipeline --restart unless-stopped \
  -e AWS_REGION=eu-north-1 \
  -e AWS_DEFAULT_REGION=eu-north-1 \
  -e CW_LOG_GROUP=/aws/gravisonde/pipeline \
  -e S3_BENCHMARK_BUCKET=gravisonde \
  -e PIPELINE_MODE=cool \
  -e DETECTION_MODEL=yolo11n.onnx \
  -e CONF_THRESHOLD=0.5 \
  -e METRICS_PUSH_INTERVAL_SEC=10 \
  -v /home/ec2-user/gravisonde/data/sample.mp4:/data/sample.mp4:ro \
  -v /home/ec2-user/gravisonde/data/yolo11n.onnx:/app/yolo11n.onnx:ro \
  gravisonde-pipeline

# 3. Watch for 30 seconds
docker logs -f gravisonde-pipeline

# 4. Verify model is loaded (should NOT see "dummy detector" warning)
docker logs gravisonde-pipeline 2>&1 | grep -i "detector initialized"

# 5. Check CloudWatch Logs (requires AWS CLI configured)
aws logs describe-log-streams \
  --log-group-name /aws/gravisonde/pipeline \
  --region eu-north-1

# 6. Tail live logs from CloudWatch
aws logs tail /aws/gravisonde/pipeline --follow --region eu-north-1
```

## Next Steps: Dashboard Integration

Since CloudWatch Metrics are blocked, update the dashboard to use CloudWatch Logs:

1. **Query CloudWatch Logs API** instead of CloudWatch Metrics
2. **Parse JSON log events** to extract frame metrics
3. **Aggregate in-memory** (P50/P95/P99 latencies, FPS, etc.)
4. **Display in real-time** on the dashboard

This keeps all the metrics flowing without requiring CloudWatch Metrics API access.

## Cost Notes

- **CloudWatch Logs**: $0.50/GB ingested, $0.03/GB stored
- **Typical ingestion**: ~100 bytes/frame = ~3MB/hour at 30fps
- **Monthly cost**: ~$0.04/month for logs alone (negligible)
- CloudWatch Metrics would have been ~$0.30/month (10 metrics @ $0.30/metric)

The SCP blocking Metrics actually saves a small amount of cost.
