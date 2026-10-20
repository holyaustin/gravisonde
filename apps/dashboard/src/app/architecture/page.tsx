import { Metadata } from "next";

export const metadata: Metadata = {
  title: "Architecture — Gravisonde",
  description: "System architecture diagram and data-flow",
};

export default function ArchitecturePage() {
  return (
    <main className="prose prose-invert prose-slate max-w-5xl mx-auto p-8 space-y-8">
      <header className="border-b border-border pb-8">
        <h1 className="text-3xl font-bold tracking-tight mb-2">Architecture</h1>
        <p className="text-text-muted">
          Data flow from live video source through OpenCV 5 pipeline to the judge's dashboard.
        </p>
      </header>

      <section>
        <h2 className="text-xl font-semibold mb-4">1. High-Level Data Flow</h2>
        <div className="border border-border bg-surface rounded-xl p-4 overflow-x-auto">
<pre className="font-mono text-xs overflow-x-auto"><code>{`flowchart LR
    subgraph Source
        CAM[Camera / Sample Video]
    end

    subgraph EC2_Graviton[EC2 c8g.xlarge - COOL AMI]
        CAP[Capture cv2.VideoCapture + ffmpeg]
        DET[Detection cv2.dnn YOLO/SSD + ALIKED]
        MET[Metrics Collector Ring Buffer + CloudWatch]
    end

    subgraph AWS_Services[AWS Services]
        CW[(CloudWatch Logs + Metrics)]
        S3[(S3 Benchmark Artifacts)]
    end

    subgraph Dashboard[Next.js 16 Dashboard - Vercel]
        SSE[/api/metrics SSE Endpoint]
        UI[Live Dashboard Video Canvas + Charts]
    end

    CAM -->|RTSP / file| CAP
    CAP -->|frames| DET
    DET -->|detections + timing| MET
    MET -->|per-frame metrics| CW
    MET -->|benchmark runs| S3
    CW -->|Logs Insights| SSE
    SSE -->|EventStream| UI
}`}</code></pre>
        </div>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-4">2. Component Layers</h2>
        <table className="w-full text-sm border-collapse">
          <thead>
            <tr className="border-b border-border">
              <th className="text-left py-2 px-3 text-text-muted">Layer</th>
              <th className="text-left py-2 px-3 text-text-muted">Component</th>
              <th className="text-left py-2 px-3 text-text-muted">Technology</th>
            </tr>
          </thead>
          <tbody className="divide-y border-border/50">
            <tr>
              <td className="py-2 px-3 font-mono">Source</td>
              <td className="py-2 px-3">Camera / sample video file</td>
              <td className="py-2 px-3">RTSP / MPEG-TS / MP4</td>
            </tr>
            <tr>
              <td className="py-2 px-3 font-mono">Compute</td>
              <td className="py-2 px-3">EC2 c8g.xlarge (Graviton4) + COOL AMI</td>
              <td className="py-2 px-3">AWS EC2 / Ubuntu 24.04 / Arm KleidiCV</td>
            </tr>
            <tr>
              <td className="py-2 px-3 font-mono">Pipeline</td>
              <td className="py-2 px-3">OpenCV 5: VideoCapture → DNN → Metrics</td>
              <td className="py-2 px-3">Python / OpenCV 5.0 / ONNX Runtime</td>
            </tr>
            <tr>
              <td className="py-2 px-3 font-mono">Observability</td>
              <td className="py-2 px-3">CloudWatch Logs + Custom Metrics + S3</td>
              <td className="py-2 px-3">AWS CloudWatch / AWS S3</td>
            </tr>
            <tr>
              <td className="py-2 px-3 font-mono">Frontend</td>
              <td className="py-2 px-3">Next.js 16 App Router + SSE + Recharts</td>
              <td className="py-2 px-3">TypeScript / React 19 / Tailwind v4</td>
            </tr>
            <tr>
              <td className="py-2 px-3 font-mono">Hosting</td>
              <td className="py-2 px-3">Dashboard on Vercel; pipeline on EC2</td>
              <td className="py-2 px-3">Vercel / AWS EC2</td>
            </tr>
          </tbody>
        </table>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-4">3. Infrastructure (CDK)</h2>
        <p className="text-text-muted leading-relaxed">
          All AWS resources are defined in <code className="bg-surface-elevated px-1.5 py-0.5 rounded">infra/</code>
          using AWS CDK (TypeScript). A single <code className="bg-surface-elevated px-1.5 py-0.5 rounded">GravisondeStack</code>
          provisions:
        </p>
        <ul className="list-disc list-inside space-y-1 text-text-muted leading-relaxed">
          <li>EC2 instance (<code className="bg-surface-elevated px-1.5 py-0.5 rounded">c8g.xlarge</code>) with COOL AMI</td>
          <li>IAM instance profile (least privilege: CloudWatch + S3)</li>
          <li>CloudWatch Log Group + custom metric namespace</li>
          <li>S3 bucket for benchmark artifacts</li>
          <li>Security group: 22 (builder SSH only), 80/443 via ALB (optional)</li>
        </ul>
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-4">4. Environment Variables</h2>
        <table className="w-full text-sm border-collapse">
          <thead>
            <tr className="border-b border-border">
              <th className="text-left py-2 px-3 text-text-muted">Variable</th>
              <th className="text-left py-2 px-3 text-text-muted">Description</th>
              <th className="text-left py-2 px-3 text-text-muted">Default</th>
            </tr>
          </thead>
          <tbody className="divide-y border-border/50">
            <tr><td className="py-2 px-3 font-mono">NEXT_PUBLIC_AWS_REGION</td><td className="py-2 px-3">AWS region</td><td className="py-2 px-3">us-east-1</td></tr>
            <tr><td className="py-2 px-3 font-mono">NEXT_PUBLIC_CW_LOG_GROUP</td><td className="py-2 px-3">CloudWatch log group</td><td className="py-2 px-3">/aws/gravisonde/pipeline</td></tr>
            <tr><td className="py-2 px-3 font-mono">NEXT_PUBLIC_INSTANCE_TYPE</td><td className="py-2 px-3">Displayed instance type</td><td className="py-2 px-3">c8g.xlarge</td></tr>
            <tr><td className="py-2 px-3 font-mono">NEXT_PUBLIC_HOURLY_COST_USD</td><td className="py-2 px-3">Fallback cost if Pricing API fails</td><td className="py-2 px-3">0.136</td></tr>
            <tr><td className="py-2 px-3 font-mono">VIDEO_SOURCE</td><td className="py-2 px-3">Pipeline input source</td><td className="py-2 px-3">/data/sample.mp4</td></tr>
            <tr><td className="py-2 px-3 font-mono">PIPELINE_MODE</td><td className="py-2 px-3">cool or stock</td><td className="py-2 px-3">cool</td></tr>
          </tbody>
        </table>
      </section>
    </main>
  );
}