// Gravisonde — shared metrics types and validation (Zod)
// Used by both dashboard (TypeScript) and pipeline (Python) via JSON contracts.

import { z } from "zod";

// ---------------------------------------------------------------------------
// Frame-level metric emitted by the pipeline every processed frame
// ---------------------------------------------------------------------------
export const FrameMetricSchema = z.object({
  ts: z.number().describe("Unix milliseconds"),
  frameId: z.number().describe("Monotonic frame id"),
  latencyMs: z.number().describe("End-to-end: capture -> detection -> emit"),
  inferenceMs: z.number().describe("DNN forward pass only"),
  detections: z.number().describe("Object count in frame"),
  instanceId: z.string().describe("EC2 instance-id"),
  opencvVersion: z.string().describe("e.g. 5.0.0.93"),
  coolVersion: z.string().optional().describe("COOL commit/version if detectable"),
  arch: z.enum(["graviton", "x86"]),
  pipeline: z.enum(["cool", "stock"]),
});

export type FrameMetric = z.infer<typeof FrameMetricSchema>;

// ---------------------------------------------------------------------------
// Aggregated metrics for dashboard cards (computed client-side from stream)
// ---------------------------------------------------------------------------
export const AggregatedMetricsSchema = z.object({
  fps: z.number(),
  p50LatencyMs: z.number(),
  p95LatencyMs: z.number(),
  p99LatencyMs: z.number(),
  avgDetections: z.number(),
  instanceType: z.string(),
  hourlyCostUsd: z.number(),
  fpsPerDollar: z.number(),
  arch: z.enum(["graviton", "x86"]),
  pipeline: z.enum(["cool", "stock"]),
  sampleCount: z.number(),
  windowStart: z.number(),
  windowEnd: z.number(),
});

export type AggregatedMetrics = z.infer<typeof AggregatedMetricsSchema>;

// ---------------------------------------------------------------------------
// Benchmark run summary (stored in S3 as JSON + CSV)
// ---------------------------------------------------------------------------
export const BenchmarkRunSchema = z.object({
  runId: z.string().uuid(),
  startedAt: z.string().datetime(),
  durationSec: z.number(),
  videoSource: z.string(),
  frameCount: z.number(),
  avgFps: z.number(),
  p50LatencyMs: z.number(),
  p95LatencyMs: z.number(),
  p99LatencyMs: z.number(),
  totalDetections: z.number(),
  estimatedCostUsd: z.number(),
  instanceType: z.string(),
  opencvVersion: z.string(),
  coolVersion: z.string().optional(),
  pipeline: z.enum(["cool", "stock"]),
  notes: z.string().optional(),
});

export type BenchmarkRun = z.infer<typeof BenchmarkRunSchema>;

// ---------------------------------------------------------------------------
// Static AWS pricing table (fallback when Pricing API is unavailable)
// Source: AWS EC2 On-Demand pricing, us-east-1, USD, per-hour
// Updated: 2026-10
// ---------------------------------------------------------------------------
export const InstanceSpecSchema = z.object({
  type: z.string(),
  vcpu: z.number(),
  memGiB: z.number(),
  hourlyUsd: z.number(),
  arch: z.enum(["graviton", "x86"]),
  coolSupported: z.boolean(),
  description: z.string(),
});

export type InstanceSpec = z.infer<typeof InstanceSpecSchema>;

export const INSTANCE_SPECS: InstanceSpec[] = [
  {
    type: "c8g.xlarge",
    vcpu: 4,
    memGiB: 8,
    hourlyUsd: 0.136,
    arch: "graviton",
    coolSupported: true,
    description: "Graviton4 — COOL-optimized baseline",
  },
  {
    type: "c7i.xlarge",
    vcpu: 4,
    memGiB: 8,
    hourlyUsd: 0.170,
    arch: "x86",
    coolSupported: false,
    description: "Intel Xeon Ice Lake — x86 comparison",
  },
  {
    type: "c6g.xlarge",
    vcpu: 4,
    memGiB: 8,
    hourlyUsd: 0.136,
    arch: "graviton",
    coolSupported: true,
    description: "Graviton3 — fallback if c8g unavailable",
  },
];

export function getHourlyCost(instanceType: string): number {
  const spec = INSTANCE_SPECS.find((s) => s.type === instanceType);
  return spec ? spec.hourlyUsd : 0;
}

export function getSpec(instanceType: string): InstanceSpec | undefined {
  return INSTANCE_SPECS.find((s) => s.type === instanceType);
}

// ---------------------------------------------------------------------------
// SSE event envelope
// ---------------------------------------------------------------------------
export const SSEEventSchema = z.object({
  type: z.enum(["metrics", "benchmark", "error"]),
  data: z.union([
    AggregatedMetricsSchema,
    BenchmarkRunSchema,
    z.object({ message: z.string() }),
  ]),
});

export type SSEEvent = z.infer<SSEEventSchema>;