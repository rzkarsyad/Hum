"use client";

import { useEffect, useState } from "react";
import { Mark } from "@/components/Mark";
import { site } from "@/lib/site";

export function Nav() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header
      className={`sticky top-0 z-50 transition-colors duration-300 ${
        scrolled
          ? "border-b border-hairline bg-paper/75 backdrop-blur-xl"
          : "border-b border-transparent"
      }`}
    >
      <nav className="flex h-16 items-center gap-3 px-6 sm:px-8">
        <a href="#top" className="flex items-center gap-2.5">
          <Mark className="size-7" />
          <span className="text-[17px] font-extrabold tracking-[-0.02em]">Hum</span>
        </a>

        <div className="ml-auto flex items-center gap-1">
          <a
            href={site.repo}
            target="_blank"
            rel="noreferrer"
            className="hidden rounded-full px-3 py-1.5 text-[14px] font-semibold text-ink-2 transition hover:bg-white hover:text-ink sm:block"
          >
            GitHub
          </a>
          <a
            href={site.releases}
            target="_blank"
            rel="noreferrer"
            className="rounded-full bg-ink px-4 py-2 text-[14px] font-bold text-white transition hover:bg-ink/85"
          >
            Download
          </a>
        </div>
      </nav>
    </header>
  );
}
