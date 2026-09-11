"use client";

import { useEffect, useState } from "react";
import { Mark } from "@/components/Mark";
import { site } from "@/lib/site";

const links = [
  { href: "#features", label: "Features" },
  { href: "#install", label: "Install" },
  { href: "#privacy", label: "Privacy" },
];

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
      <nav className="mx-auto flex h-16 max-w-6xl items-center gap-4 px-6">
        <a href="#top" className="flex items-center gap-2.5">
          <Mark className="size-7" />
          <span className="text-[17px] font-extrabold tracking-[-0.02em]">Hum</span>
        </a>

        <ul className="ml-4 hidden items-center gap-1 sm:flex">
          {links.map((link) => (
            <li key={link.href}>
              <a
                href={link.href}
                className="rounded-full px-3 py-1.5 text-[14px] font-semibold text-ink-2 transition hover:bg-paper-2 hover:text-ink"
              >
                {link.label}
              </a>
            </li>
          ))}
        </ul>

        <div className="ml-auto flex items-center gap-1">
          <a
            href={site.repo}
            target="_blank"
            rel="noreferrer"
            className="hidden rounded-full px-3 py-1.5 text-[14px] font-semibold text-ink-2 transition hover:bg-paper-2 hover:text-ink sm:block"
          >
            GitHub
          </a>
          <a
            href="#install"
            className="rounded-full bg-ink px-4 py-2 text-[14px] font-bold text-white transition hover:bg-ink/85"
          >
            Download
          </a>
        </div>
      </nav>
    </header>
  );
}
