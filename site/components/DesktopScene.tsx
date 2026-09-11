import { LyricsWindow } from "@/components/LyricsWindow";

/** Faint rounded bar standing in for a menu title or status glyph. */
function Bar({ w }: { w: number }) {
  return (
    <span
      className="block h-[5px] rounded-full bg-[#0b1020]/25"
      style={{ width: w }}
      aria-hidden="true"
    />
  );
}

/**
 * A stylised Mac desktop: pastel wallpaper, menu bar with Hum's note sitting in
 * it, and the floating lyrics window over the top. Tells the whole story of the
 * app in one frame — where it lives, and what it puts on screen.
 */
export function DesktopScene() {
  return (
    <div className="relative mx-auto w-full max-w-5xl">
      <div
        className="relative aspect-[16/10] overflow-hidden rounded-[22px] ring-1 ring-black/5 sm:rounded-[28px]"
        style={{
          background: `
            radial-gradient(75% 60% at 12% 8%, #cfe0ff 0%, transparent 60%),
            radial-gradient(65% 55% at 88% 12%, #ffd9ec 0%, transparent 62%),
            radial-gradient(80% 70% at 78% 92%, #c9efff 0%, transparent 60%),
            radial-gradient(70% 60% at 22% 88%, #e3dcff 0%, transparent 62%),
            linear-gradient(160deg, #eef3ff 0%, #f6f1fb 52%, #eaf6ff 100%)
          `,
          boxShadow:
            "0 2px 4px rgba(9,9,16,0.04), 0 24px 60px -28px rgba(9,9,16,0.28)",
        }}
      >
        {/* Menu bar */}
        <div className="flex h-7 items-center gap-3 bg-white/45 px-3.5 backdrop-blur-md sm:h-8 sm:px-4">
          <svg viewBox="0 0 24 24" className="size-3 text-[#0b1020]/50" fill="currentColor" aria-hidden="true">
            <path d="M16.4 12.7c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.2-2.8.9-3.5.9s-1.8-.8-3-.8c-1.5 0-3 .9-3.8 2.3-1.6 2.8-.4 7 1.2 9.3.8 1.1 1.7 2.4 2.9 2.3 1.2 0 1.6-.7 3-.7s1.8.7 3 .7 2-1.1 2.8-2.2c.9-1.3 1.2-2.5 1.3-2.6-.1 0-2.5-1-2.5-3.9ZM14.2 5.6c.6-.8 1.1-1.9 1-3-1 0-2.2.7-2.9 1.5-.6.7-1.2 1.8-1 2.9 1.1 0 2.2-.6 2.9-1.4Z" />
          </svg>
          <span className="hidden items-center gap-3 sm:flex">
            <Bar w={26} />
            <Bar w={18} />
            <Bar w={22} />
            <Bar w={16} />
          </span>

          <span className="ml-auto flex items-center gap-3">
            {/* Hum's note, sitting where it actually sits */}
            <span className="relative grid place-items-center">
              <span className="absolute -inset-1.5 rounded-md bg-white/70 ring-1 ring-brand/25" aria-hidden="true" />
              <svg viewBox="0 0 24 24" className="relative size-3 text-[#0b1020]/75" fill="currentColor" aria-hidden="true">
                <path d="M20 3.5v11.2a3.3 3.3 0 1 1-1.8-2.94V6.6l-7.4 1.68v8.77a3.3 3.3 0 1 1-1.8-2.94V6.02L20 3.5Z" />
              </svg>
            </span>
            <span className="hidden items-center gap-2.5 sm:flex">
              <Bar w={13} />
              <Bar w={11} />
            </span>
            <span className="text-[10px] font-semibold text-[#0b1020]/55 tabular-nums">
              9:41
            </span>
          </span>
        </div>

        {/* The floating window */}
        <div className="absolute inset-x-0 bottom-0 flex justify-center px-4 pb-[6%]">
          <LyricsWindow />
        </div>
      </div>
    </div>
  );
}
