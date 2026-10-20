"use client";

import { useState } from "react";

interface MetricCardProps {
  label: string;
  value: string;
  unit: string;
  trend?: "up" | "down" | "neutral";
}

export function MetricCard({
  label,
  value,
  unit,
  trend = "neutral",
}: MetricCardProps) {
  const [hovered, setHovered] = useState(false);

  const trendColor =
    trend === "up"
      ? "text-success/80 hover:text-success"
      : trend === "down"
        ? "text-danger/80 hover:text-danger"
        : "text-text-muted/60 hover:text-text";

  return (
    <div className="metric-card relative overflow-hidden group">
      <div className="absolute inset-0 bg-primary/5 opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none" />
      <div className="relative z-10">
        <div className="flex items-center justify-between mb-2">
          <h3 className="text-sm font-medium text-text">{label}</h3>
          <span
            className={`
              inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium border
              ${trendColor}
            `}
          >
            {trend === "up" && (
              <span className="w-2 h-2 rounded-full bg-current" aria-hidden="true" />
            )}
            {trend === "down" && (
              <span className="w-2 h-2 rounded-full bg-current" aria-hidden="true" />
            )}
          </span>
        </div>
        <p className="metric-value text-text">{value}</p>
        <p className="text-xs text-text-muted">{unit}</p>
      </div>
    </div>
  );
}