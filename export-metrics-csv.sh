#!/bin/bash
# Quick CSV Export from Running Pipeline
# Usage: ./export-metrics-csv.sh [output_file.csv]

OUTPUT_FILE="${1:-benchmark_$(date +%Y%m%d_%H%M%S).csv}"

echo "Exporting metrics from LocalStack CloudWatch Logs to: $OUTPUT_FILE"

# Check if LocalStack is running
if ! curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
    echo "ERROR: LocalStack is not running. Start with: docker compose up -d"
    exit 1
fi

# Export metrics from CloudWatch Logs
echo "Fetching metrics from CloudWatch Logs..."

aws logs filter-log-events \
  --log-group-name /aws/gravisonde/pipeline \
  --start-time $(($(date +%s) - 3600))000 \
  --endpoint-url http://localhost:4566 \
  --region eu-north-1 \
  --no-sign-request \
  --output json 2>/dev/null | \
  jq -r '
    # Add CSV header
    "frameId,timestamp,latencyMs,inferenceMs,detections,instanceId,opencvVersion,coolVersion,arch,pipeline",
    # Extract and format each log event
    (.events[].message | fromjson |
      [.frameId, .ts, .latencyMs, .inferenceMs, .detections, .instanceId, .opencvVersion, (.coolVersion // "N/A"), .arch, .pipeline] |
      @csv
    )
  ' > "$OUTPUT_FILE"

# Check if file was created and has data
if [ -f "$OUTPUT_FILE" ]; then
    LINE_COUNT=$(wc -l < "$OUTPUT_FILE")
    if [ "$LINE_COUNT" -gt 1 ]; then
        echo "✓ Success! Exported $((LINE_COUNT - 1)) frames to: $OUTPUT_FILE"
        echo ""
        echo "First 5 rows:"
        head -n 6 "$OUTPUT_FILE" | column -t -s,
        echo ""
        echo "File size: $(ls -lh "$OUTPUT_FILE" | awk '{print $5}')"
    else
        echo "⚠ Warning: No metrics found. Pipeline may not be running or no data collected yet."
        rm -f "$OUTPUT_FILE"
        exit 1
    fi
else
    echo "✗ Error: Failed to create CSV file"
    exit 1
fi
