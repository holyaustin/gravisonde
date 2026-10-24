import type { NextConfig } from "next";

const nextConfig: NextConfig = {
   output: 'standalone',
  // Image optimization for demo assets
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "**",
      },
    ],
  },
  // Headers for SSE
  async headers() {
    return [
      {
        source: "/api/metrics",
        headers: [
          { key: "Cache-Control", value: "no-cache, no-transform" },
          { key: "Connection", value: "keep-alive" },
          { key: "Content-Type", value: "text/event-stream" },
          { key: "X-Accel-Buffering", value: "no" },
        ],
      },
    ];
  },
};

export default nextConfig;