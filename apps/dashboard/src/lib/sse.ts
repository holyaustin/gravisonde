// Gravisonde — SSE client helper
// Connects to /api/metrics and yields AggregatedMetrics events.

import { AggregatedMetrics, SSEEvent, SSEEventSchema } from "./metrics";

export type MetricsStreamHandler = (metrics: AggregatedMetrics) => void;
export type ErrorHandler = (err: Error) => void;

export interface MetricsStreamOptions {
  onMetrics: MetricsStreamHandler;
  onError?: ErrorHandler;
  reconnectDelayMs?: number;
  maxRetries?: number;
}

/**
 * Connect to the metrics SSE stream with automatic reconnect.
 * Yields AggregatedMetrics objects as they arrive.
 *
 * @example
 * const stream = connectMetricsStream({ onMetrics: setMetrics });
 * // cleanup: stream.close()
 */
export function connectMetricsStream({
  onMetrics,
  onError,
  reconnectDelayMs = 3000,
  maxRetries = 10,
}: MetricsStreamOptions): { close: () => void } {
  let es: EventSource | null = null;
  let retries = 0;
  let closed = false;

  function connect() {
    if (closed) return;
    es = new EventSource("/api/metrics");

    es.onmessage = (ev: MessageEvent) => {
      try {
        const parsed = JSON.parse(ev.data) as unknown;
        const event = SSEEventSchema.parse(parsed);
        if (event.type === "metrics") {
          onMetrics(event.data as AggregatedMetrics);
        }
      } catch (err) {
        console.warn("[SSE] parse error", err);
      }
    };

    es.onerror = (err) => {
      console.warn("[SSE] connection error", err);
      es?.close();
      if (closed) return;
      if (retries < maxRetries) {
        retries++;
        setTimeout(connect, reconnectDelayMs * Math.min(retries, 5));
      } else {
        onError?.(new Error("SSE stream exhausted retries"));
      }
    };

    es.addEventListener("benchmark", (ev: MessageEvent) => {
      try {
        const parsed = JSON.parse(ev.data) as unknown;
        const event = SSEEventSchema.parse(parsed);
        if (event.type === "benchmark") {
          // Handled by BenchmarkDownload component
          window.dispatchEvent(
            new CustomEvent("gravisonde:benchmark", { detail: event.data })
          );
        }
      } catch {
        // ignore
      }
    });
  }

  connect();

  return {
    close() {
      closed = true;
      es?.close();
    },
  };
}

/**
 * Fetch a single snapshot of aggregated metrics (for static/server rendering).
 */
export async function fetchMetricsSnapshot(): Promise<AggregatedMetrics | null> {
  try {
    const res = await fetch("/api/metrics", { cache: "no-store" });
    if (!res.ok) return null;
    const data = await res.json();
    return AggregatedMetricsSchema.parse(data);
  } catch {
    return null;
  }
}