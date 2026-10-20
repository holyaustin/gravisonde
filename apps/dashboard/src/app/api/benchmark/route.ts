import { NextRequest, NextResponse } from "next/server";
import { BenchmarkRunSchema, BenchmarkRun } from "@/lib/metrics";
import crypto from "crypto";

export const dynamic = "force-dynamic";
export const revalidate = 0;

// In-memory store for benchmark runs (dev only — production persists to S3)
const benchmarkRuns = new Map<string, BenchmarkRun>();

export async function POST(req: NextRequest): Promise<NextResponse> {
  try {
    const body = await req.json();
    const {
      durationSec = 60,
      pipeline = "cool",
      videoSource = "local-file",
    } = body;

    const runId = crypto.randomUUID();
    const startedAt = new Date().toISOString();

    // Emit a benchmark-started SSE event so the UI can react
    // (fire-and-forget; clients listening on /api/metrics with benchmark listener)
    const run: BenchmarkRun = BenchmarkRunSchema.parse({
      runId,
      startedAt,
      durationSec,
      videoSource,
      frameCount: 0,
      avgFps: 0,
      p50LatencyMs: 0,
      p95LatencyMs: 0,
      p99LatencyMs: 0,
      totalDetections: 0,
      estimatedCostUsd: 0,
      instanceType: "c8g.xlarge",
      opencvVersion: "5.0.0.93",
      coolVersion: undefined,
      pipeline,
      notes: `Started via dashboard at ${startedAt}`,
    });

    benchmarkRuns.set(runId, run);

    return NextResponse.json({ ok: true, runId, startedAt });
  } catch (err) {
    return NextResponse.json({ ok: false, error: String(err) }, { status: 400 });
  }
}

export async function GET(req: NextRequest): Promise<NextResponse> {
  const { searchParams } = new URL(req.url);
  const runId = searchParams.get("runId");

  if (runId) {
    const run = benchmarkRuns.get(runId);
    if (!run) {
      return NextResponse.json({ ok: false, error: "run not found" }, { status: 404 });
    }
    return NextResponse.json({ ok: true, run });
  }

  // List recent runs
  const runs = Array.from(benchmarkRuns.values()).sort(
    (a, b) => new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime()
  );
  return NextResponse.json({ ok: true, runs: runs.slice(0, 50) });
}