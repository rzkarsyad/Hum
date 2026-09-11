import type { CSSProperties, ReactNode } from "react";

/**
 * Entrance animation for above-the-fold content. Pure CSS, so it plays whether
 * or not the bundle has hydrated, and the end state is simply "visible".
 */
export function Intro({
  children,
  delay = 0,
  className = "",
}: {
  children: ReactNode;
  delay?: number;
  className?: string;
}) {
  return (
    <div
      className={`hum-intro ${className}`}
      style={{ "--d": `${delay}ms` } as CSSProperties}
    >
      {children}
    </div>
  );
}
