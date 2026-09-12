import Image from "next/image";

import { Dock, MenuBar } from "@/components/MacChrome";
import { LyricsWindow } from "@/components/LyricsWindow";

/**
 * A stylised Mac desktop: pastel wallpaper, menu bar with Hum's note sitting in
 * it, and the floating lyrics window over the top. Tells the whole story of the
 * app in one frame: where it lives, and what it puts on screen.
 */
export function DesktopScene() {
  return (
    <div className="mx-auto w-full max-w-[820px]">
      {/* Lid. The face of a modern MacBook is black glass edge to edge, so the
          bezel and the body read as one piece. */}
      <div className="mx-auto w-[93.5%] rounded-t-[16px] rounded-b-[5px] bg-[#1b1b1e] px-[1.1%] pt-[1.1%] pb-[1.6%] ring-1 ring-white/10">
        {/* 20/13 = 1.5385; the measured panel is 1470/956 = 1.5377, within 0.05%. */}
        <div className="relative aspect-[20/13] overflow-hidden rounded-[9px] bg-black">
          <Image
            src="/wallpaper.webp"
            alt=""
            fill
            priority
            sizes="(max-width: 768px) 100vw, 760px"
            className="object-cover"
          />
          <MenuBar />

          {/* Notch. Measured off a MacBook Air 13.6": the panel is 1470x956pt
              and NSScreen reports a 179pt notch, so 12.18% of screen width. Its
              height tracks the menu bar because macOS grows the bar to 32pt on
              notched Macs, exactly the notch height. It lands between the menu
              titles and the status items, so it never covers either. */}
          <div
            className="absolute inset-x-0 top-0 z-10 mx-auto h-[3.35%] w-[12.18%] rounded-b-[5px] bg-[#1b1b1e]"
            aria-hidden="true"
          />

          <div className="absolute inset-x-0 bottom-0 flex justify-center px-4 pb-[13%]">
            <div className="w-[60%] min-w-[280px] max-w-[500px]">
              <LyricsWindow />
            </div>
          </div>
          <Dock />
        </div>
      </div>

      {/* Base: the aluminium edge you see under the lid, with the finger
          groove cut out of the front. */}
      <div className="relative h-[11px] w-full rounded-b-[9px] bg-[#b6b6bb] shadow-[0_18px_28px_-18px_rgba(9,9,16,0.5)] sm:h-[13px]">
        <div className="absolute inset-x-0 top-0 mx-auto h-[45%] w-[13%] rounded-b-[6px] bg-[#9d9da3]" aria-hidden="true" />
      </div>
    </div>
  );
}

/**
 * Phone-sized version of the same idea. The full desktop frame is unreadable
 * below 768px, so this drops the menu bar and chrome and keeps what matters:
 * the window floating on the wallpaper.
 */
export function CompactScene() {
  return (
    <div
      className="relative mx-auto w-full max-w-[440px] overflow-hidden rounded-[22px] px-4 pt-9 pb-7 ring-1 ring-black/5"
      style={{
        boxShadow:
          "0 2px 4px rgba(9,9,16,0.04), 0 24px 60px -28px rgba(9,9,16,0.28)",
      }}
    >
      <Image
        src="/wallpaper.webp"
        alt=""
        fill
        sizes="100vw"
        className="object-cover"
      />
      <div className="relative">
        <LyricsWindow />
      </div>
    </div>
  );
}
