import { NextRequest, NextResponse } from "next/server";
import { FrameMetricSchema } from "@/lib/metrics";

export const dynamic = "force-dynamic";
export const revalidate = 0;

// In-memory ring buffer for the last N frame metrics.
// In production this would read from CloudWatch Logs Insights or Metrics API.
const METRICS_WINDOW = 10000;
const ringBuffer: FrameMetric[] = [];
let writeIdx = 0;
let bufferFull = false;

/**
 * Called by the CV pipeline (via HTTP POST) to push a frame metric.
 * Accepts both FrameMetric and partial frames for demo resilience.
 */
export async function POST(req: NextRequest): Promise<NextResponse> {
  try {
    const body = await req.json();

    // Support single metric or array of metrics
    const metrics = Array.isArray(body) ? body : [body];

    for (const m of metrics) {
      const parsed = FrameMetricSchema.safeParse(m);
      if (!parsed.success) {
        // Skip malformed frames instead of failing the whole batch
        console.warn("[api/metrics] invalid frame skipped", parsed.error.flatten());
        continue;
      }
      ringBuffer[writeIdx] = parsed.data;
      writeIdx = (writeIdx + 1) % METRICS_WINDOW;
      if (writeIdx === 0) bufferFull = true;
    }

    return NextResponse.json({ ok: true, pushed: metrics.length });
  } catch (err) {
    return NextResponse.json({ ok: false, error: String(err) }, { status: 400 });
  }
}

/**
 * SSE endpoint: streams aggregated metrics at ~1 Hz.
 * Reads from the in-memory ring buffer (populated by POST above or CloudWatch).
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const streamController = new TransformStream();
  const writer = streamController.writable.getWriter();

  // Store the writer so GET can close the stream on abort
  // (Next.js does not expose req.signal reliably for SSE, so we use a timer-based approach)
  let lastLen = 0;
  let consecutiveEmpty = 0;
  let intervalId: NodeJS.Timeout | null = null;

  async function pushLoop() {
    try {
      while (true) {
        const len = bufferFull ? METRICS_WINDOW : writeIdx;
        if (len > 0 && len !== lastLen) {
          const recent: typeof ringBuffer = bufferFull
            ? [...ringBuffer.slice(writeIdx), ...ringBuffer.slice(0, writeIdx)]
            : ringBuffer.slice(0, writeIdx);

          const aggregated = aggregateMetrics(recent);
          const payload = new TextEncoder().encode(
            `data: ${JSON.stringify({ type: "metrics", data: aggregated })}\n\n`
          );
          await writer.write(payload);
          lastLen = len;
          consecutiveEmpty = 0;
        } else if (len === 0) {
          consecutiveEmpty++;
          if (consecutiveEmpty > 5) {
            const empty = new TextEncoder().encode(
              `data: ${JSON.stringify({ type: "metrics", data: emptyAggregated() })}\n\n`
            );
            await writer.write(empty);
            consecutiveEmpty = 0;
          }
        }

        // Wait 1s between pushes
        await new Promise((resolve) => setTimeout(resolve, 1000));
      }
    } catch (err) {
      // Stream was closed by client
      console.log("[SSE] client disconnected");
    } finally {
      if (intervalId) clearInterval(intervalId);
      try {
        await writer.close();
      } catch {
        // Already closed
      }
    }
  }

  pushLoop();

  return new NextResponse(streamController.readable, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
      "X-Accel-Buffering": "no",
    },
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function percentile(sorted: number[], p: number): number {
  if (sorted.length === 0) return 0;
  const idx = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.max(0, Math.min(sorted.length - 1, idx))];
}

function aggregateMetrics(metrics: FrameMetric[]): AggregatedMetrics {
  const sortedLatency = metrics
    .map((m) => m.latencyMs)
    .sort((a, b) => a - b);
  const now = Date.now();
  const windowStart = metrics.length > 0 ? metrics[0]!.ts : now - 1000;
  const windowEnd = now;

  const fps =
    metrics.length > 0 ? (metrics.length / ((windowEnd - windowStart) / 1000)) : 0;
  const avgDetections =
    metrics.length > 0
      ? metrics.reduce((sum, m) => sum + m.detections, 0) / metrics.length
      : 0;

  const specMap: Record<string, { hourly: number; arch: "graviton" | "x86" }> = {
    "c8g.xlarge": { hourly: 0.136, arch: "graviton" },
    "c7i.xlarge": { hourly: 0.17, arch: "x86" },
    "c6g.xlarge": { hourly: 0.136, arch: "graviton" },
  };

  // Note: instanceId from metrics is EC2 instance-id (not type).
  // For display, we default to c8g.xlarge since that's our configured instance.
  const instanceType = "c8g.xlarge";
  const hourlyCost = 0.136;
  const arch = "graviton" as const;
  const pipeline =
    metrics.length > 0 ? metrics[metrics.length - 1]!.pipeline : "cool";

  const fpsPerDollar = hourlyCost > 0 ? fps / hourlyCost : 0;

  return {
    fps: Math.round(fps * 100) / 100,
    p50LatencyMs: Math.round(percentile(sortedLatency, 50) * 100) / 100,
    p95LatencyMs: Math.round(percentile(sortedLatency, 95) * 100) / 100,
    p99LatencyMs: Math.round(percentile(sortedLatency, 99) * 100) / 100,
    avgDetections: Math.round(avgDetections * 100) / 100,
    instanceType,
    hourlyCostUsd: hourlyCost,
    fpsPerDollar: Math.round(fpsPerDollar * 100) / 100,
    arch,
    pipeline,
    sampleCount: metrics.length,
    windowStart,
    windowEnd,
  };
}

function emptyAggregated(): AggregatedMetrics {
  return {
    fps: 0,
    p50LatencyMs: 0,
    p95LatencyMs: 0,
    p99LatencyMs: 0,
    avgDetections: 0,
    instanceType: "c8g.xlarge",
    hourlyCostUsd: 0.136,
    fpsPerDollar: 0,
    arch: "graviton",
    pipeline: "cool",
    sampleCount: 0,
    windowStart: Date.now() - 1000,
    windowEnd: Date.now(),
  };
}

// Import type for return typing
import type { AggregatedMetrics } from "@/lib/metrics";