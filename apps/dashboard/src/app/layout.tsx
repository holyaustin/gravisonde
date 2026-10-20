// Gravisonde — Next.js 16 App Router layout
// Provides shared providers and styling

import "./globals.css";
import { ReactNode } from "react";

export const metadata = {
  title: "Gravisonde — OpenCV 5 COOL Benchmark",
  description: "Live demonstration of AWS Graviton + Cloud-Optimized OpenCV Library",
};

export default function RootLayout({
  children,
}: {
  children: ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <body>
        <div className="min-h-screen flex flex-col bg-surface text-text">
          {children}
        </div>
      </body>
    </html>
  );
}