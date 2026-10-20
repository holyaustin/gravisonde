import { AggregatedMetrics } from "@/lib/metrics";

interface InstanceBadgeProps {
  instanceType: string;
  pipeline: "cool" | "stock";
  arch: "graviton" | "x86";
}

export function InstanceBadge({ instanceType, pipeline, arch }: InstanceBadgeProps) {
  return (
    <div className="flex items-center gap-2 flex-wrap">
      <span className="badge badge-graviton">
        {arch === "graviton" ? "🔧" : "⚙️"} {arch}
      </span>
      {pipeline === "cool" && (
        <span className="badge badge-cool">❄️ COOL</span>
      )}
      <span className="badge bg-surface-elevated/90 text-text border-border">
        {instanceType}
      </span>
    </div>
  );
}