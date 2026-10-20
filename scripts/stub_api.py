"""Stub AWS service emulator for local development.

Simulates CloudWatch Logs/Metrics and S3 endpoints so the dashboard
can develop and test without real AWS credentials or a running EC2.
Based on the LocalStack pattern but minimal and in-process.

Run: python scripts/stub_api.py --port 4566
"""

import argparse
import json
import time
import threading
import queue
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

# Shared state
metric_buffer = queue.Queue(maxsize=10000)
metrics_history = []
lock = threading.Lock()


class StubHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        qs = parse_qs(parsed.query)

        if path == "/":
            self.send_json({"status": "ok", "service": "gravisonde-stub"})

        elif path == "/metrics/v1/data/Gravisonde":
            # Return aggregated metrics
            with lock:
                if metrics_history:
                    latest = metrics_history[-1]
                else:
                    latest = {
                        "fps": 0, "p50LatencyMs": 0, "p95LatencyMs": 0,
                        "p99LatencyMs": 0, "avgDetections": 0,
                        "instanceType": "c8g.xlarge", "arch": "graviton",
                        "pipeline": "cool", "hourlyCostUsd": 0.136,
                        "fpsPerDollar": 0, "sampleCount": 0,
                        "windowStart": int((time.time() - 1) * 1000),
                        "windowEnd": int(time.time() * 1000),
                    }
            self.send_json(latest)

        elif path == "/health":
            self.send_json({"status": "healthy", "buffer_size": metric_buffer.qsize()})

        else:
            self.send_error(404, f"Unknown path: {path}")

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")

        content_len = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_len)

        if path == "/metrics/v1/data/Gravisonde":
            # Accept frame metrics
            try:
                data = json.loads(body) if body else {}
            except json.JSONDecodeError:
                self.send_error(400, "Invalid JSON")
                return
            with lock:
                metrics_history.append(data)
                if len(metrics_history) > 1000:
                    metrics_history.pop(0)
            self.send_json({"ok": True})
        else:
            self.send_error(404, f"Unknown path: {path}")

    def send_json(self, data, status=200):
        payload = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):
        print(f"[stub-api] {fmt % args}")


def main():
    parser = argparse.ArgumentParser(description="Gravisonde stub AWS API")
    parser.add_argument("--port", type=int, default=4566, help="Port to listen on")
    args = parser.parse_args()

    server = HTTPServer(("0.0.0.0", args.port), StubHandler)
    print(f"Stub API listening on :{args.port}")
    server.serve_forever()


if __name__ == "__main__":
    main()