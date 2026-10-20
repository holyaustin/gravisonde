import { Metadata } from "next";

export const metadata: Metadata = {
  title: "Technical Report — Gravisonde",
  description: "OpenCV AI Competition 2026 technical report",
};

export default function ReportPage() {
  return (
    <main className="prose prose-invert prose-slate max-w-4xl mx-auto p-8 space-y-8">
      <header className="border-b border-border pb-8">
        <h1 className="text-3xl font-bold tracking-tight mb-2">Technical Report</h1>
        <p className="text-text-muted">Gravisonde — OpenCV AI Competition 2026</p>
      </header>

      <section>
        <h2 className="text-xl font-semibold mb-4">1. Problem & Target Users</h2>
        <p className="text-text-muted leading-relaxed">
          Computer-vision workloads are CPU-bound and expensive on x86 instances. AWS Graviton (Arm) promises
          20–40% better price-performance, but most teams still run stock OpenCV on x86 because the migration
          path and evidence are opaque. Gravisonde provides a reproducible, live, end-to-end pipeline that proves
          the gain on real video with OpenCV 5 and the Cloud-Optimized OpenCV Library (COOL).
        </p>
        <p className="mt-2 text-text-muted leading-relaxed">
          <strong>Target users:</strong> Hackathon judges (primary), OpenCV/AWS engineers, edge/ops teams
          evaluating Graviton migration for CV workloads.
        </p>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-4">2. Proposed Solution</h2>
        <p className="text-text-muted leading-relaxed">
          A live video analytics service running OpenCV 5 object detection on an AWS Graviton4 instance
          (<code className="bg-surface-elevated px-1.5 py-0.5 rounded">c8g.xlarge</code>) using the COOL AMI.
          The pipeline captures frames, runs inference via OpenCV's new DNN engine (with ONNX Runtime backend),
          and emits per-frame metrics to CloudWatch. A Next.js 16 dashboard streams these metrics in real time
          via Server-Sent Events and displays live FPS, latency percentiles, and cost-efficiency (fps/$).
        </p>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-4">3. What Makes It Meaningfully Different</h2>
        <ul className="list-disc list-inside space-y-2 text-text-muted leading-relaxed">
          <li>Directly targets the <strong>COOL Award</strong> ($1,000) by proving COOL on Graviton beats stock x86.</li>
          <li>Uses <strong>OpenCV 5</strong> — new DNN engine (64% ONNX spec), ALIKED features, LightGlue matcher.</li>
          <li>Live, measurable demo — judges see real numbers updating in <strong>under 5 seconds</strong>.</li>
          <li>Reproducible: one-command deploy (<code className="bg-surface-elevated px-1.5 py-0.5 rounded">make deploy-infra</code>),
              benchmark CSV download, public repo with <code className="bg-surface-elevated px-1.5 py-0.5 rounded">docker-compose.yml</code> for local dev.</li>
        </ul>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-4">4. Why OpenCV 5 + AWS Are Necessary</h2>
        <ul className="list-disc list-inside space-y-2 text-text-muted leading-relaxed">
          <li><strong>OpenCV 5:</strong> The new DNN engine with ORT integration is required to run modern ONNX models
              (YOLO11n) efficiently. ALIKED/LightGlue showcase the new Features2D module.</li>
          <li><strong>AWS Graviton + COOL:</strong> COOL is a Graviton-optimized OpenCV 5 build (Arm KleidiCV).
              It's only available as an AWS Marketplace AMI — making AWS mandatory, not optional.</li>
        </ul>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-4">5. Core User Journey</h2>
        <ol className="list-decimal list-inside space-y-2 text-text-muted leading-relaxed">
          <li>Judge opens <code className="bg-surface-elevated px-1.5 py-0.5 rounded">https://gravisonde.demo</code></li>
          <li>Sees live video with bounding boxes updating at 25+ FPS</li>
          <li>Reads top-bar: <code className="bg-surface-elevated px-1.5 py-0.5 rounded">c8g.xlarge • COOL 5.0.0 • 28.4 fps • $0.136/hr • 209 fps/$</code></li>
          <li>Clicks "Download Benchmark" → gets CSV with 5,000+ frames of raw timing data</li>
          <li>Opens GitHub repo → reads README → sees <code className="bg-surface-elevated px-1.5 py-0.5 rounded">make up</code> reproduces it locally</li>
        </ol>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-4">6. Minimum Viable Product (MVP)</h2>
        <table className="w-full text-sm border-collapse">
          <thead>
            <tr className="border-b border-border">
              <th className="text-left py-2 px-3 text-text-muted">Feature</th>
              <th className="text-left py-2 px-3 text-text-muted">Description</th>
              <th className="text-left py-2 px-3 text-text-muted">Judging Criterion</th>
            </tr>
          </thead>
          <tbody>
            <tr className="border-b border-border/50">
              <td className="py-2 px-3 font-mono">Video ingestion</td>
              <td className="py-2 px-3">RTSP/file → ffmpeg → OpenCV VideoCapture</td>
              <td className="py-2 px-3">Substantive OpenCV 5 usage</td>
            </tr>
            <tr className="border-b border-border/50">
              <td className="py-2 px-3 font-mono">Detection pipeline</td>
              <td className="py-2 px-3">YOLO11n (DNN) + ALIKED/LightGlue (Features2D)</td>
              <td className="py-2 px-3">OpenCV 5 new features</td>
            </tr>
            <tr className="border-b border-border/50">
              <td className="py-2 px-3 font-mono">COOL runtime</td>
              <td className="py-2 px-3">Pipeline runs on COOL AMI on c8g.xlarge</td>
              <td className="py-2 px-3">COOL Award requirement</td>
            </tr>
            <tr className="border-b border-border/50">
              <td className="py-2 px-3 font-mono">Metrics collection</td>
              <td className="py-2 px-3">Per-frame timing → CloudWatch + ring buffer</td>
              <td className="py-2 px-3">Evidence & technical quality</td>
            </tr>
            <tr className="border-b border-border/50">
              <td className="py-2 px-3 font-mono">Next.js 16 dashboard</td>
              <td className="py-2 px-3">App Router, Cache Components, Tailwind v4</td>
              <td className="py-2 px-3">Working demo + modern stack</td>
            </tr>
            <tr className="border-b border-border/50">
              <td className="py-2 px-3 font-mono">Live metrics UI</td>
              <td className="py-2 px-3">Real-time charts via SSE</td>
              <td className="py-2 px-3">Demo quality</td>
            </tr>
            <tr className="border-b border-border/50">
              <td className="py-2 px-3 font-mono">Architecture diagram</td>
              <td className="py-2 px-3">Mermaid diagram in repo</td>
              <td className="py-2 px-3">Required deliverable</td>
            </tr>
            <tr className="border-b border-border/50">
              <td className="py-2 px-3 font-mono">Technical report</td>
              <td className="py-2 px-3">Markdown with responsible-use section</td>
              <td className="py-2 px-3">Required deliverable</td>
            </tr>
            <tr className="border-b border-border/50">
              <td className="py-2 px-3 font-mono">Demo video (≤5 min)</td>
              <td className="py-2 px-3">Scripted walkthrough</td>
              <td className="py-2 px-3">Required deliverable</td>
            </tr>
          </tbody>
        </table>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-4">7. Stretch Features</h2>
        <ul className="list-disc list-inside space-y-2 text-text-muted leading-relaxed">
          <li>Side-by-side comparison: toggle COOL vs Stock in same dashboard</li>
          <li>Kinesis Video Streams for multi-camera ingestion</li>
          <li>Multi-region failover with CloudWatch cross-region dashboards</li>
          <li>Automated nightly benchmark CI on Graviton self-hosted runner</li>
        </ul>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-4">8. Technical Architecture</h2>
        <p className="text-text-muted leading-relaxed">
          See <a href="/architecture" className="text-primary hover:underline">/architecture</a> for the interactive diagram.
          Summary: Camera → EC2 Graviton (COOL AMI) → CloudWatch/S3 → Next.js 16 (Vercel) → Judge's browser.
        </p>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-4">9. Evaluation Evidence & Limitations</h2>
        <h3 className="font-medium mb-2 text-text">Evidence Collected</h3>
        <ul className="list-disc list-inside space-y-1 text-text-muted leading-relaxed">
          <li>Per-frame CSV: timestamp, latency_ms, inference_ms, detections, instance_id, versions</li>
          <li>CloudWatch custom metrics: FPS, p50/p95/p99 latency, detection rate</li>
          <li>Benchmark report: COOL vs Stock comparison on identical hardware (AMI swap)</li>
        </ul>
        <h3 className="font-medium mb-2 text-text mt-4">Known Limitations</h3>
        <ul className="list-disc list-inside space-y-1 text-text-muted leading-relaxed">
          <li>Single-instance variance — no statistical significance across fleet</li>
          <li>Video source bias — results specific to sample content (Big Buck Bunny / CC0 footage)</li>
          <li>COOL AMI version pinning — gains may differ with future COOL releases</li>
          <li>Model quantization effects not evaluated (FP32 vs FP16 vs INT8)</li>
          <li>Network latency not included (local file source used)</li>
        </ul>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-4">10. Responsible Use</h2>
        <p className="text-text-muted leading-relaxed">
          No PII collected; video is processed locally on EC2, never uploaded. The demo uses only CC0/public-domain
          sample videos. No facial recognition, biometric analysis, or surveillance capabilities are implemented.
          The system is designed for performance benchmarking, not production deployment.
        </p>
      </section>
    </main>
  );
}