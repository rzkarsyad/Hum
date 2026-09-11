"use client";

import {
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
} from "react";
import {
  DEMO_ITEMS,
  DEMO_LOOP,
  DEMO_STILL,
  DEMO_TRACK,
  activeItemIndex,
  dotFill,
  itemDuration,
} from "@/lib/demo";

/* Distance-from-active opacities, straight out of KaraokeView.lineOpacity. The
   active line reads lowest because a full-white reveal layer stacks on top. */
const NEAR_OPACITY = [0.3, 0.45, 0.28];
const FAR_OPACITY = 0.15;

function opacityFor(index: number, active: number) {
  const d = Math.abs(index - active);
  return d < NEAR_OPACITY.length ? NEAR_OPACITY[d] : FAR_OPACITY;
}

function usePrefersReducedMotion() {
  const [reduced, setReduced] = useState(false);
  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    const sync = () => setReduced(mq.matches);
    sync();
    mq.addEventListener("change", sync);
    return () => mq.removeEventListener("change", sync);
  }, []);
  return reduced;
}

/** Playhead in seconds, looping. Parked at a still frame when `running` is off. */
function useDemoClock(running: boolean) {
  const [t, setT] = useState(DEMO_STILL);
  useEffect(() => {
    if (!running) return;
    let raf = 0;
    // Pick up from the still frame, so resuming never jumps mid-word.
    const origin = performance.now() - DEMO_STILL * 1000;
    const tick = (now: number) => {
      setT(((now - origin) / 1000) % DEMO_LOOP);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [running]);
  return running ? t : DEMO_STILL;
}

/** A sung line: dim base text with a per-character reveal layered over it. */
function LyricLine({
  text,
  isActive,
  duration,
  dim,
}: {
  text: string;
  isActive: boolean;
  duration: number;
  dim: number;
}) {
  const chars = useMemo(() => Array.from(text), [text]);
  // Spread the reveal across the line's whole window, so the last glyph lands
  // just as the next line takes over — the same pacing as the app.
  const stagger = Math.max((duration - 0.42) / Math.max(chars.length, 1), 0.01);

  return (
    <div className="relative">
      <span className="text-white" style={{ opacity: isActive ? NEAR_OPACITY[0] : dim }}>
        {text}
      </span>
      {isActive && (
        <span className="absolute inset-0 text-white" aria-hidden="true">
          {chars.map((c, i) => (
            <span
              key={i}
              className="hum-char"
              style={{ "--d": `${(i * stagger).toFixed(3)}s` } as CSSProperties}
            >
              {c}
            </span>
          ))}
        </span>
      )}
    </div>
  );
}

function Dots({ fills, size }: { fills: number[]; size: number }) {
  return (
    <div className="flex items-center" style={{ gap: size * 0.9 }}>
      {fills.map((fill, i) => (
        <span
          key={i}
          className="rounded-full bg-white"
          style={{
            width: size,
            height: size,
            opacity: 0.25 + 0.75 * fill,
            transition: "opacity 90ms linear",
          }}
        />
      ))}
    </div>
  );
}

function GlassButton({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <span
      aria-label={label}
      role="img"
      className="grid size-[22px] place-items-center rounded-full bg-white/15 text-white/80 ring-1 ring-white/15 backdrop-blur-sm"
    >
      {children}
    </span>
  );
}

export function LyricsWindow({ className = "" }: { className?: string }) {
  const rootRef = useRef<HTMLDivElement>(null);
  const viewportRef = useRef<HTMLDivElement>(null);
  const itemRefs = useRef<(HTMLDivElement | null)[]>([]);

  const [inView, setInView] = useState(false);
  const [offset, setOffset] = useState(0);
  const reduced = usePrefersReducedMotion();

  // Don't burn frames while the window is scrolled out of sight.
  useEffect(() => {
    const el = rootRef.current;
    if (!el) return;
    const io = new IntersectionObserver(
      ([entry]) => setInView(entry.isIntersecting),
      { threshold: 0.2 },
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);

  const t = useDemoClock(inView && !reduced);
  const active = activeItemIndex(t);
  const fontSize = 20;

  // Centre the active item. Measured rather than assumed, so a wrapped line
  // still lands in the middle.
  useLayoutEffect(() => {
    const recentre = () => {
      const viewport = viewportRef.current;
      const el = itemRefs.current[active];
      if (!viewport || !el) return;
      setOffset(viewport.clientHeight / 2 - (el.offsetTop + el.offsetHeight / 2));
    };
    recentre();
    window.addEventListener("resize", recentre);
    return () => window.removeEventListener("resize", recentre);
  }, [active]);

  return (
    <div
      ref={rootRef}
      className={`w-full max-w-[500px] overflow-hidden rounded-2xl bg-[#16161b]/85 ring-1 ring-white/10 backdrop-blur-2xl ${className}`}
      style={{ boxShadow: "0 40px 80px -24px rgba(10, 12, 26, 0.55)" }}
    >
      {/* Header — artwork, track, controls. 60px, matching HumLayout.headerHeight. */}
      <div className="flex h-[60px] items-center gap-2.5 px-3 py-2.5">
        <div className="relative size-10 shrink-0 overflow-hidden rounded-md bg-brand">
          <svg
            viewBox="0 0 24 24"
            className="absolute inset-0 m-auto size-5 text-white/90"
            fill="currentColor"
            aria-hidden="true"
          >
            <path d="M20 3.5v11.2a3.3 3.3 0 1 1-1.8-2.94V6.6l-7.4 1.68v8.77a3.3 3.3 0 1 1-1.8-2.94V6.02L20 3.5Z" />
          </svg>
        </div>
        <div className="min-w-0 flex-1">
          <p className="truncate text-[13px] font-bold text-white">{DEMO_TRACK.title}</p>
          <p className="truncate text-[11px] text-white/70">{DEMO_TRACK.artist}</p>
        </div>
        <div className="flex items-center gap-2">
          <GlassButton label="Collapse">
            <svg viewBox="0 0 16 16" className="size-2.5" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M3 10l5-5 5 5" />
            </svg>
          </GlassButton>
          <GlassButton label="Hide lyrics">
            <svg viewBox="0 0 20 20" className="size-3" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round">
              <path d="M3 3l14 14M8.2 4.4A7.3 7.3 0 0 1 10 4.2c4 0 7 3.3 7 5.8 0 .9-.5 2-1.4 3M5.3 6.1C3.8 7.2 3 8.7 3 10c0 2.5 3 5.8 7 5.8 1 0 2-.2 2.8-.6" />
              <path d="M8.3 8.4a2.4 2.4 0 0 0 3.3 3.3" />
            </svg>
          </GlassButton>
        </div>
      </div>

      {/* Lyrics viewport */}
      <div
        ref={viewportRef}
        className="relative h-[184px] overflow-hidden"
        style={{
          maskImage:
            "linear-gradient(to bottom, transparent 0%, #000 12%, #000 86%, transparent 100%)",
          WebkitMaskImage:
            "linear-gradient(to bottom, transparent 0%, #000 12%, #000 86%, transparent 100%)",
        }}
        aria-label={`Synced lyrics for ${DEMO_TRACK.title}`}
      >
        <div
          className="relative px-4"
          style={{
            transform: `translateY(${offset}px)`,
            transition: reduced
              ? "none"
              : "transform 550ms cubic-bezier(0.22, 1, 0.36, 1)",
          }}
        >
          {DEMO_ITEMS.map((item, i) => {
            const isActive = i === active;
            const dim = opacityFor(i, active);
            return (
              <div
                key={i}
                ref={(el) => {
                  itemRefs.current[i] = el;
                }}
                className="py-[5px] font-bold"
                style={{
                  fontSize,
                  lineHeight: 1.25,
                  transform: `scale(${isActive ? 1 : 0.96})`,
                  transformOrigin: "left center",
                  transition: reduced
                    ? "none"
                    : "transform 450ms cubic-bezier(0.22, 1, 0.36, 1)",
                }}
              >
                {item.kind === "lyric" ? (
                  <LyricLine
                    text={item.text}
                    isActive={isActive}
                    duration={itemDuration(i)}
                    dim={dim}
                  />
                ) : (
                  <div style={{ opacity: isActive ? 1 : dim }}>
                    <Dots
                      size={Math.max(8, fontSize * 0.32)}
                      fills={[0, 1, 2].map((d) =>
                        isActive
                          ? dotFill(
                              d,
                              Math.min(
                                Math.max((t - item.start) / (item.end - item.start), 0),
                                1,
                              ),
                            )
                          : 0,
                      )}
                    />
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
