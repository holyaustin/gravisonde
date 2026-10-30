import { NextRequest, NextResponse } from "next/server";
import { BenchmarkRunSchema, BenchmarkRun } from "@/lib/metrics";
import { awsClientConfig } from "@/lib/aws-config";
import { S3Client, PutObjectCommand, GetObjectCommand, ListObjectsV2Command } from "@aws-sdk/client-s3";
import crypto from "crypto";

export const dynamic = "force-dynamic";
export const revalidate = 0;

const s3 = new S3Client({ ...awsClientConfig, forcePathStyle: !!process.env.AWS_ENDPOINT_URL });
const BUCKET = process.env.NEXT_PUBLIC_S3_BUCKET!;
const PREFIX = "benchmarks/";

export async function POST(req: NextRequest): Promise<NextResponse> {
  try {
    const body = await req.json();
    const durationSec = body.durationSec ?? 60;
    const runId = crypto.randomUUID();
    const startedAt = new Date().toISOString();

    const run: BenchmarkRun = BenchmarkRunSchema.parse({
      runId,
      startedAt,
      durationSec,
      videoSource: body.videoSource ?? "local-file",
      frameCount: 0,
      avgFps: 0,
      p50LatencyMs: 0,
      p95LatencyMs: 0,
      p99LatencyMs: 0,
      totalDetections: 0,
      estimatedCostUsd: 0,
      instanceType: "c8g.xlarge",
      opencvVersion: "5.0.0.93",
      pipeline: body.pipeline ?? "cool",
      notes: `Started via dashboard at ${startedAt}`,
    });

    await s3.send(new PutObjectCommand({
      Bucket: BUCKET,
      Key: `${PREFIX}run-${runId}.json`,
      Body: JSON.stringify(run),
      ContentType: "application/json",
    }));

    await s3.send(new PutObjectCommand({
      Bucket: BUCKET,
      Key: `${PREFIX}run-${runId}.csv`,
      Body: "index,fps,p50_ms,p99_ms\n",
      ContentType: "text/csv",
    }));

    return NextResponse.json({ ok: true, runId, startedAt });
  } catch (err) {
    return NextResponse.json({ ok: false, error: String(err) }, { status: 400 });
  }
}

export async function GET(req: NextRequest): Promise<NextResponse> {
  try {
    const { searchParams } = new URL(req.url);
    const runId = searchParams.get("runId");

    if (runId) {
      const obj = await s3.send(new GetObjectCommand({ Bucket: BUCKET, Key: `${PREFIX}run-${runId}.json` }));
      const body = await obj.Body?.transformToString() ?? "{}";
      const run = BenchmarkRunSchema.parse(JSON.parse(body));
      return NextResponse.json({ ok: true, run });
    }

    const list = await s3.send(new ListObjectsV2Command({ Bucket: BUCKET, Prefix: PREFIX, MaxKeys: 50 }));
    const runs: BenchmarkRun[] = [];
    for (const item of list.Contents ?? []) {
      if (item.Key?.endsWith(".json")) {
        try {
          const obj = await s3.send(new GetObjectCommand({ Bucket: BUCKET, Key: item.Key! }));
          const body = await obj.Body?.transformToString() ?? "{}";
          runs.push(BenchmarkRunSchema.parse(JSON.parse(body)));
        } catch {}
      }
    }
    runs.sort((a,b)=> new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime());
    return NextResponse.json({ ok: true, runs });
  } catch {
    return NextResponse.json({ ok: true, run: null, runs: [] });
  }
}