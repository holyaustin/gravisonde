"use client";

import { useRef, useEffect } from "react";
import { AggregatedMetrics } from "@/lib/metrics";

interface LiveVideoCanvasProps {
  metrics: AggregatedMetrics | null;
  className?: string;
}

export function LiveVideoCanvas({ metrics, className }: LiveVideoCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    const ctx = canvas?.getContext("2d");
    if (!canvas || !ctx) return;

    let frame = 0;
    const width = canvas.width;
    const height = canvas.height;

    function draw() {
      if (!ctx) return;
      const t = Date.now() / 1000;
      const fps = metrics?.fps ?? 0;
      const detections = metrics?.avgDetections ?? 0;

      // Clear background with subtle gradient
      const grad = ctx.createLinearGradient(0, 0, width, height);
      grad.addColorStop(0, "#0f172a");
      grad.addColorStop(1, "#1e293b");
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, width, height);

      // Draw a subtle grid (camera frame lookalike)
      ctx.strokeStyle = "#334155";
      ctx.lineWidth = 1;
      for (let i = 0; i <= width; i += 40) {
        ctx.beginPath();
        ctx.moveTo(i, 0);
        ctx.lineTo(i, height);
        ctx.stroke();
      }
      for (let i = 0; i <= height; i += 40) {
        ctx.beginPath();
        ctx.moveTo(0, i);
        ctx.lineTo(width, i);
        ctx.stroke();
      }

      // Draw pulsing "recording" frame border
      const pulse = (Math.sin(t * 4) + 1) / 2;
      ctx.strokeStyle = `rgba(16, 185, 129, ${0.4 + pulse * 0.4})`;
      ctx.lineWidth = 3;
      ctx.strokeRect(10, 10, width - 20, height - 20);

      // Draw simulated bounding boxes from detections
      ctx.fillStyle = "rgba(14, 165, 233, 0.9)";
      ctx.font = "bold 14px system-ui";
      ctx.fillText("PERSON", 60, 40);
      ctx.fillText("VEHICLE", 200, 120);

      if (detections > 0) {
        const boxCount = Math.min(Math.ceil(detections), 4);
        const boxes = [
          { x: width * 0.3, y: height * 0.3, w: width * 0.25, h: height * 0.25 },
          { x: width * 0.55, y: height * 0.45, w: width * 0.2, h: height * 0.2 },
          { x: width * 0.15, y: height * 0.6, w: width * 0.18, h: height * 0.18 },
          { x: width * 0.7, y: height * 0.2, w: width * 0.15, h: height * 0.15 },
        ];
        boxes.slice(0, boxCount).forEach((box, i) => {
          const bob = Math.sin(t * 3 + i) * 2;
          ctx.strokeStyle = "#0ea5e9";
          ctx.lineWidth = 2;
          ctx.strokeRect(box.x, box.y + bob, box.w, box.h);
          ctx.fillStyle = "#0ea5e9";
          ctx.fillRect(box.x, box.y - 20 + bob, 50, 16);
          ctx.fillStyle = "#ffffff";
          ctx.font = "bold 12px system-ui";
          ctx.fillText("person", box.x + 4, box.y - 8 + bob);
        });
      }

      // FPS overlay
      ctx.fillStyle = "rgba(15, 23, 42, 0.7)";
      ctx.fillRect(10, height - 34, 120, 24);
      ctx.fillStyle = "#22d3ee";
      ctx.font = "bold 14px system-ui";
      ctx.fillText(`FPS: ${fps.toFixed(1)}`, 18, height - 16);

      frame++;
      requestAnimationFrame(draw);
    }

    draw();
  }, [metrics]);

  return (
    <canvas ref={canvasRef} className={className} aria-label="Live video feed — OpenCV 5 object detection overlay" />
  );
}