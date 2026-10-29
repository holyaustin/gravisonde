const nextConfig = {
  output: process.env.VERCEL ? undefined : 'standalone',
  images: {
    remotePatterns: [{ protocol: "https", hostname: "**" }],
  },
  async headers() {
    return [{
      source: "/api/metrics",
      headers: [
        { key: "Cache-Control", value: "no-cache, no-transform" },
        { key: "Connection", value: "keep-alive" },
        { key: "Content-Type", value: "text/event-stream" },
        { key: "X-Accel-Buffering", value: "no" },
      ],
    }];
  },
};

module.exports = nextConfig;