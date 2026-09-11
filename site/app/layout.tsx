import type { Metadata } from "next";
import { Nunito } from "next/font/google";
import { site } from "@/lib/site";
import "./globals.css";

const nunito = Nunito({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
  variable: "--font-nunito",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: `${site.name} — ${site.tagline}`,
  description:
    "Hum floats synced lyrics above everything you're doing. Apple Music, Spotify, or whatever's playing in a browser tab. Native, tiny, and it never asks for an account.",
  applicationName: site.name,
  keywords: [
    "lyrics",
    "karaoke",
    "macOS",
    "menu bar app",
    "Apple Music",
    "Spotify",
    "synced lyrics",
    "LRCLIB",
  ],
  openGraph: {
    type: "website",
    title: `${site.name} — ${site.tagline}`,
    description:
      "Synced lyrics that float above every window, for Apple Music, Spotify and the browser.",
    url: site.url,
    siteName: site.name,
  },
  twitter: {
    card: "summary_large_image",
    title: `${site.name} — ${site.tagline}`,
    description:
      "Synced lyrics that float above every window, for Apple Music, Spotify and the browser.",
  },
  icons: { icon: "/icon.png", apple: "/icon.png" },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={nunito.variable}>
      <body className="antialiased">{children}</body>
    </html>
  );
}
