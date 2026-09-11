import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Fully static — drops into GitHub Pages, Vercel, Netlify or any bucket.
  output: "export",
  images: { unoptimized: true },
};

export default nextConfig;
