"use client";

import { useRef, useEffect, useState } from "react";
import { AggregatedMetrics } from "@/lib/metrics";
import {
  LineChart,
  Line,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";

interface MetricsChartsProps {
  metrics: AggregatedMetrics | null;
}

const MAX_POINTS = 60; // Keep last 60 data points (~1 minute at 1 Hz)

export function MetricsCharts({ metrics }: MetricsChartsProps) {
  const [fpsHistory, setFpsHistory] = useState<number[]>([]);
  const [latencyP50History, setLatencyP50History] = useState<number[]>([]);
  const [latencyP99History, setLatencyP99History] = useState<number[]>([]);
  const [detectionsHistory, setDetectionsHistory] = useState<number[]>([]);

  // Update history when new metrics arrive
  useEffect(() => {
    if (!metrics) return;
    setFpsHistory((prev) => [...prev.slice(-(MAX_POINTS - 1)), metrics.fps]);
    setLatencyP50History((prev) => [...prev.slice(-(MAX_POINTS - 1)), metrics.p50LatencyMs]);
    setLatencyP99History((prev) => [...prev.slice(-(MAX_POINTS - 1)), metrics.p99LatencyMs]);
    setDetectionsHistory((prev) => [...prev.slice(-(MAX_POINTS - 1)), metrics.avgDetections]);
  }, [metrics]);

  const data = fpsHistory.map((_, i) => ({
    time: `${i}s`,
    fps: fpsHistory[i],
    p50: latencyP50History[i],
    p99: latencyP99History[i],
    detections: detectionsHistory[i],
  }));

  if (data.length === 0) {
    return (
      <div className="flex-1 flex items-center justify-center text-text-muted">
        <p>Waiting for metrics...</p>
      </div>
    );
  }

  const customTooltip = ({ active, payload, label }: { active?: boolean; payload?: Array<{ value: number; name: string; color: string }>; label?: string }) => {
    if (!active || !payload) return null;
    return (
      <div className="bg-surface-elevated border border-border rounded-lg p-3 shadow-lg">
        <p className="font-mono text-sm text-text-muted mb-2">{label}</p>
        {payload.map((entry, i) => (
          <p key={i} className="text-sm flex items-center gap-2" style={{ color: entry.color }}>
            <span className="w-2 h-2 rounded-full" style={{ background: entry.color }} />
            {entry.name}: {entry.value.toFixed(2)}
          </p>
        ))}
      </div>
    );
  };

  return (
    <div className="flex-1 space-y-4">
      {/* FPS Chart */}
      <div className="h-[140px]">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={data} margin={{ top: 5, right: 5, left: 0, bottom: 0 }}>
            <defs>
              <linearGradient id="fpsGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#0ea5e9" stopOpacity={0.4} />
                <stop offset="95%" stopColor="#0ea5e9" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#334155" vertical={false} />
            <XAxis
              dataKey="time"
              stroke="#64748b"
              fontSize={11}
              tickLine={false}
              axisLine={false}
              tick={{ fill: "#64748b" }}
            />
            <YAxis
              stroke="#64748b"
              fontSize={11}
              tickLine={false}
              axisLine={false}
              tick={{ fill: "#64748b" }}
              tickFormatter={(v) => `${v}`}
              domain={[0, "auto"]}
            />
            <Tooltip content={customTooltip} />
            <Legend wrapperStyle={{ paddingTop: 5 }} />
            <Area
              type="monotone"
              dataKey="fps"
              name="FPS"
              stroke="#0ea5e9"
              fill="url(#fpsGradient)"
              strokeWidth={2}
              dot={false}
              isAnimationActive={false}
            />
          </AreaChart>
        </ResponsiveContainer>
        <div className="flex items-center justify-between text-xs mt-1">
          <span className="text-text-muted">FPS</span>
          <span className="font-mono text-primary">{data[data.length - 1]?.fps.toFixed(1) ?? "—"}</span>
        </div>
      </div>

      {/* Latency Chart */}
      <div className="h-[140px]">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={data} margin={{ top: 5, right: 5, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#334155" vertical={false} />
            <XAxis
              dataKey="time"
              stroke="#64748b"
              fontSize={11}
              tickLine={false}
              axisLine={false}
              tick={{ fill: "#64748b" }}
            />
            <YAxis
              stroke="#64748b"
              fontSize={11}
              tickLine={false}
              axisLine={false}
              tick={{ fill: "#64748b" }}
              tickFormatter={(v) => `${v}ms`}
              domain={[0, "auto"]}
            />
            <Tooltip content={customTooltip} />
            <Legend wrapperStyle={{ paddingTop: 5 }} />
            <Line
              type="monotone"
              dataKey="p50"
              name="p50"
              stroke="#22c55e"
              strokeWidth={2}
              dot={false}
              isAnimationActive={false}
            />
            <Line
              type="monotone"
              dataKey="p99"
              name="p99"
              stroke="#f59e0b"
              strokeWidth={2}
              dot={false}
              strokeDasharray="5 5"
              isAnimationActive={false}
            />
          </LineChart>
        </ResponsiveContainer>
        <div className="flex items-center justify-between text-xs mt-1">
          <span className="text-text-muted">Latency (ms)</span>
          <span className="font-mono text-success">p50: {data[data.length - 1]?.p50.toFixed(1) ?? "—"}ms</span>
          <span className="font-mono text-warning">p99: {data[data.length - 1]?.p99.toFixed(1) ?? "—"}ms</span>
        </div>
      </div>

      {/* Detections Chart */}
      <div className="h-[100px]">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={data} margin={{ top: 5, right: 5, left: 0, bottom: 0 }}>
            <defs>
              <linearGradient id="detGradient" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#22c55e" stopOpacity={0.4} />
                <stop offset="95%" stopColor="#22c55e" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#334155" vertical={false} />
            <XAxis
              dataKey="time"
              stroke="#64748b"
              fontSize={11}
              tickLine={false}
              axisLine={false}
              tick={{ fill: "#64748b" }}
            />
            <YAxis
              stroke="#64748b"
              fontSize={11}
              tickLine={false}
              axisLine={false}
              tick={{ fill: "#64748b" }}
              domain={[0, "auto"]}
            />
            <Tooltip content={customTooltip} />
            <Area
              type="monotone"
              dataKey="detections"
              name="Detections/frame"
              stroke="#22c55e"
              fill="url(#detGradient)"
              strokeWidth={2}
              dot={false}
              isAnimationActive={false}
            />
          </AreaChart>
        </ResponsiveContainer>
        <div className="flex items-center justify-between text-xs mt-1">
          <span className="text-text-muted">Avg Detections/Frame</span>
          <span className="font-mono text-success">{data[data.length - 1]?.detections.toFixed(1) ?? "—"}</span>
        </div>
      </div>
    </div>
  );
}