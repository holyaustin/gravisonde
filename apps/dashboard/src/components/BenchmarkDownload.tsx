"use client";

import { useState } from "react";
import { AggregatedMetrics, BenchmarkRun } from "@/lib/metrics";

export function BenchmarkDownload() {
  const [downloading, setDownloading] = useState(false);
  const [lastRun, setLastRun] = useState<BenchmarkRun | null>(null);
  const [generating, setGenerating] = useState(false);

  async function startBenchmark(durationSec: number) {
    setGenerating(true);
    try {
      const res = await fetch("/api/benchmark", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ durationSec, pipeline: "cool", videoSource: "local-file" }),
      });
      if (!res.ok) throw new Error("Failed to start benchmark");
      const { runId } = await res.json();
      console.log(`Benchmark started: ${runId}`);
      // Poll for completion (mock: simulate shortly)
      setTimeout(() => {
        fetch(`/api/benchmark?runId=${runId}`)
          .then((r) => r.json())
          .then((data) => {
            setLastRun(data.run ?? null);
          })
          .catch(() => {});
      }, 2000);
    } catch (err) {
      console.error("Benchmark error", err);
    } finally {
      setGenerating(false);
    }
  }

  function exportCsv() {
    // Export a sample CSV of recent metrics
    const metrics = localStorage.getItem("gravisonde:recent-metrics");
    let data = "";
    if (metrics) {
      const arr = JSON.parse(metrics);
      data = arr.map((m: Record<string, unknown>, i: number) => `${i},${m.fps},${m.p50LatencyMs},${m.p99LatencyMs}`).join("\n");
    }
    if (!data) return;
    const blob = new Blob([`index,fps,p50_ms,p99_ms\n${data}`], { type: "text/csv" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `gravisonde-bench_${Date.now()}.csv`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 100);
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-3">
        <button
          className="btn btn-primary"
          onClick={() => startBenchmark(60)}
          disabled={generating}
        >
          {generating ? "Running…" : "▶ Start 60s Benchmark"}
        </button>
        <button
          className="btn btn-secondary"
          onClick={() => startBenchmark(120)}
          disabled={generating}
        >
          {generating ? "Running…" : "▶ Start 120s Benchmark"}
        </button>
        <button className="btn btn-secondary" onClick={exportCsv}>
          ⬇ Download CSV
        </button>
      </div>

      {lastRun && (
        <div className="card border-l-4 border-l-sky-500">
          <h3 className="font-semigruv bold text-sm mb-2">Latest Benchmark Result</h3>
          <table className="w-full text-sm font-mono">
            <tbody>
              <tr><td className="py-1 px-2 text-text-muted">Run ID</td><td className="px-2 break-all">{lastRun.runId}</td></tr>
              <tr><td className="py-1 px-2 text-text-muted">Duration</td><td className="px-2">{lastRun.durationSec}s</td></tr>
              <tr><td className="py-1 px-2 text-text-muted">Frames</td><td className="px-2">{lastRun.frameCount}</td></tr>
              <tr><td className="py-1 px-2 text-text-muted">Avg FPS</td><td className="px-2 text-success">{lastRun.avgFps}</td></tr>
              <tr><td className="py-1 px-2 text-text-muted">p50 Latency</td><td className="px-2">{lastRun.p50LatencyMs}ms</td></tr>
              <tr><td className="py-1 px-2 text-text-muted">p99 Latency</td><td className="px-2">{lastRun.p99LatencyMs}ms</td></tr>
              <tr><td className="py-1 px-2 text-text-muted">Cost</td><td className="px-2">${lastRun.estimatedCostUsd}/hr</td></tr>
              <tr><td className="py-1 px-2 text-text-muted">Pipeline</td><td className="px-2">{lastRun.pipeline === "cool" ? "COOL" : "Stock"}</td></tr>
              <tr><td className="py-1 px-2 text-text-muted">OpenCV</td><td className="px-2">{lastRun.opencvVersion}</td></tr>
              {lastRun.notes && <tr><td className="py-1 px-2 text-text-muted">Notes</td><td className="px-2 break-all">{lastRun.notes}</td></tr>}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
