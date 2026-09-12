"use client";

import { useEffect, useLayoutEffect, useRef, useState, type ReactNode } from "react";

/**
 * Lifts its children into place the first time they scroll into view.
 *
 * Starts *visible* and only hides itself in a layout effect, and only if it is
 * genuinely below the fold. So a slow, broken or disabled bundle leaves a fully
 * readable page instead of a blank one, and nothing ever flashes.
 *
 * For content that is on screen at load, use `Intro` instead.
 */
export function Reveal({
  children,
  delay = 0,
  className = "",
}: {
  children: ReactNode;
  delay?: number;
  className?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [hidden, setHidden] = useState(false);

  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    // Already on screen, so leave it alone rather than animating under the reader.
    if (el.getBoundingClientRect().top < window.innerHeight * 0.9) return;
    setHidden(true);
  }, []);

  useEffect(() => {
    if (!hidden) return;
    const el = ref.current;
    if (!el) return;
    const io = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setHidden(false);
          io.disconnect();
        }
      },
      { threshold: 0.1, rootMargin: "0px 0px -6% 0px" },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [hidden]);

  return (
    <div
      ref={ref}
      className={className}
      style={{
        opacity: hidden ? 0 : 1,
        transform: hidden ? "translateY(18px)" : "none",
        transition:
          "opacity 700ms var(--ease-out-soft), transform 700ms var(--ease-out-soft)",
        transitionDelay: `${delay}ms`,
      }}
    >
      {children}
    </div>
  );
}
