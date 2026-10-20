"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { connectMetricsStream } from "@/lib/sse";
import { AggregatedMetrics } from "@/lib/metrics";
import { MetricCard } from "@/components/MetricCard";
import { LiveVideoCanvas } from "@/components/LiveVideoCanvas";
import { MetricsCharts } from "@/components/MetricsCharts";
import { InstanceBadge } from "@/components/InstanceBadge";
import { BenchmarkDownload } from "@/components/BenchmarkDownload";

export default function DashboardPage() {
  const [metrics, setMetrics] = useState<AggregatedMetrics | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const streamRef = useRef<ReturnType<typeof connectMetricsStream> | null>(null);

  useEffect(() => {
    setError(null);
    setIsConnected(false);

    const stream = connectMetricsStream({
      onMetrics: (m) => {
        setMetrics(m);
        setIsConnected(true);
      },
      onError: (err) => {
        setError(err.message);
        setIsConnected(false);
      },
    });

    streamRef.current = stream;

    return () => {
      stream.close();
    };
  }, []);

  if (!metrics && error) {
    return (
      <div className="flex-1 flex items-center justify-center p-8">
        <div className="text-center">
          <div className="text-danger text-4xl mb-4">⚠️</div>
          <h2 className="text-xl font-semibold mb-2">Connection Lost</h2>
          <p className="text-text-muted mb-4">{error}</p>
          <p className="text-sm text-text-muted">Retrying automatically...</p>
        </div>
      </div>
    );
  }

  return (
    <main className="flex-1 p-4 md:p-6 lg:p-8 space-y-6">
      {/* Header */}
      <header className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold tracking-tight">
            Gravisonde
          </h1>
          <p className="text-text-muted mt-1">
            OpenCV 5 on AWS Graviton — COOL performance benchmark
          </p>
        </div>
        <div className="flex items-center gap-3">
          <InstanceBadge
            instanceType={metrics?.instanceType ?? "c8g.xlarge"}
            pipeline={metrics?.pipeline ?? "cool"}
            arch={metrics?.arch ?? "graviton"}
          />
          <span
            className={`flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium ${
              isConnected
                ? "bg-success/20 text-success border-success/30"
                : "bg-warning/20 text-warning border-warning/30"
            } border`}
          >
            <span className="w-1.5 h-1.5 rounded-full bg-current" />
            {isConnected ? "Live" : "Connecting…"}
          </span>
        </div>
      </header>

      {/* Metric Cards */}
      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <MetricCard
          label="FPS"
          value={metrics?.fps?.toFixed(1) ?? "—"}
          unit="frames/sec"
          trend={metrics && metrics.fps > 25 ? "up" : "neutral"}
        />
        <MetricCard
          label="Latency (p50)"
          value={metrics?.p50LatencyMs?.toFixed(1) ?? "—"}
          unit="ms"
          trend={metrics && metrics.p50LatencyMs < 40 ? "up" : "neutral"}
        />
        <MetricCard
          label="Latency (p99)"
          value={metrics?.p99LatencyMs?.toFixed(1) ?? "—"}
          unit="ms"
          trend={metrics && metrics.p99LatencyMs < 80 ? "up" : "neutral"}
        />
        <MetricCard
          label="FPS / $"
          value={metrics?.fpsPerDollar?.toFixed(0) ?? "—"}
          unit="fps per $/hr"
          trend={metrics && metrics.fpsPerDollar > 180 ? "up" : "neutral"}
        />
      </section>

      {/* Main Content: Video + Charts */}
      <section className="grid lg:grid-cols-2 gap-6">
        {/* Video Feed */}
        <div className="card relative min-h-[400px]">
          <h2 className="text-lg font-semibold mb-4">Live Video Feed</h2>
          <div className="relative w-full aspect-video">
            <LiveVideoCanvas
              metrics={metrics}
              className="w-full h-full"
            />
            {/* Overlay badges */}
            <div className="absolute top-3 left-3 flex flex-col gap-1">
              <span className="badge badge-cool">COOL</span>
              <span className="badge badge-graviton">Graviton</span>
            </div>
            <div className="absolute top-3 right-3 flex gap-1">
              {metrics && (
                <>
                  <span className="badge bg-surface-elevated/90 border-border">
                    {metrics.avgDetections.toFixed(1)} det/frame
                  </span>
                  <span className="badge bg-surface-elevated/90 border-border">
                    {metrics.fps.toFixed(1)} fps
                  </span>
                </>
              )}
            </div>
          </div>
        </div>

        {/* Charts */}
        <div className="card min-h-[400px] flex flex-col">
          <h2 className="text-lg font-semibold mb-4">Real-Time Metrics</h2>
          <div className="flex-1 min-h-0">
            <MetricsCharts metrics={metrics} />
          </div>
        </div>
      </section>

      {/* Benchmark Section */}
      <section className="card">
        <h2 className="text-lg font-semibold mb-4">Benchmark & Evidence</h2>
        <BenchmarkDownload />
      </section>

      {/* Footer */}
      <footer className="text-center text-sm text-text-muted py-4 border-t border-border">
        <p>
          Built for the <strong>OpenCV AI Competition 2026</strong> — COOL Award track
        </p>
        <p className="mt-1">
          AWS Graviton (c8g.xlarge) + Cloud-Optimized OpenCV Library (COOL) + OpenCV 5.0
        </p>
      </footer>
    </main>
  );
}