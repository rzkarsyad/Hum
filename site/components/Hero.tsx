import { CopyField } from "@/components/CopyField";
import { DesktopScene } from "@/components/DesktopScene";
import { LyricsWindow } from "@/components/LyricsWindow";
import { Reveal } from "@/components/Reveal";
import { site } from "@/lib/site";

export function Hero() {
  return (
    <section id="top" className="relative overflow-hidden">
      {/* Soft bloom, in the app-icon blues */}
      <div className="pointer-events-none absolute inset-x-0 top-0 -z-10 h-[760px]" aria-hidden="true">
        <div className="absolute left-1/2 top-[-260px] size-[900px] -translate-x-1/2 rounded-full bg-[radial-gradient(circle,rgba(90,200,250,0.22)_0%,transparent_66%)]" />
        <div className="absolute left-[12%] top-[60px] size-[560px] rounded-full bg-[radial-gradient(circle,rgba(10,132,255,0.14)_0%,transparent_68%)]" />
        <div className="absolute right-[8%] top-[20px] size-[520px] rounded-full bg-[radial-gradient(circle,rgba(255,140,200,0.14)_0%,transparent_68%)]" />
      </div>

      <div className="mx-auto max-w-6xl px-6 pt-14 pb-16 text-center sm:pt-20">
        <Reveal>
          <a
            href={site.changelog}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-2 rounded-full border border-hairline bg-white/70 py-1.5 pl-2 pr-3.5 text-[13px] font-semibold text-ink-2 shadow-[0_1px_2px_rgba(9,9,16,0.04)] backdrop-blur transition hover:border-brand/30 hover:text-ink"
          >
            <span className="rounded-full bg-brand/10 px-2 py-0.5 text-[12px] font-bold text-brand">
              v{site.version}
            </span>
            Spotify and browser support are here
            <span aria-hidden="true" className="text-ink-3">&rarr;</span>
          </a>
        </Reveal>

        <Reveal delay={80}>
          <h1 className="headline mx-auto mt-7 max-w-[14ch] text-[clamp(2.75rem,7.4vw,5.25rem)]">
            Every word,
            <br />
            <span className="bg-gradient-to-r from-brand-3 via-brand to-brand-2 bg-clip-text text-transparent">
              right on time.
            </span>
          </h1>
        </Reveal>

        <Reveal delay={150}>
          <p className="mx-auto mt-6 max-w-[46ch] text-[17px] leading-[1.55] font-medium text-ink-2 sm:text-[19px]">
            Hum floats synced lyrics above everything you&rsquo;re doing. Apple Music,
            Spotify, or whatever&rsquo;s playing in a browser tab &mdash; it just knows.
          </p>
        </Reveal>

        <Reveal delay={210}>
          <div className="mx-auto mt-9 flex max-w-xl flex-col items-center gap-3 sm:flex-row sm:justify-center">
            <a
              href={site.releases}
              target="_blank"
              rel="noreferrer"
              className="inline-flex w-full shrink-0 items-center justify-center gap-2 rounded-full bg-brand px-6 py-3.5 text-[15px] font-bold text-white shadow-[0_10px_28px_-10px_rgba(10,132,255,0.7)] transition hover:bg-brand-3 sm:w-auto"
            >
              <svg viewBox="0 0 24 24" className="size-[18px]" fill="currentColor" aria-hidden="true">
                <path d="M16.4 12.7c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.2-2.8.9-3.5.9s-1.8-.8-3-.8c-1.5 0-3 .9-3.8 2.3-1.6 2.8-.4 7 1.2 9.3.8 1.1 1.7 2.4 2.9 2.3 1.2 0 1.6-.7 3-.7s1.8.7 3 .7 2-1.1 2.8-2.2c.9-1.3 1.2-2.5 1.3-2.6-.1 0-2.5-1-2.5-3.9ZM14.2 5.6c.6-.8 1.1-1.9 1-3-1 0-2.2.7-2.9 1.5-.6.7-1.2 1.8-1 2.9 1.1 0 2.2-.6 2.9-1.4Z" />
              </svg>
              Download for Mac
            </a>
            <CopyField value={site.brew} label="the Homebrew command" className="sm:max-w-[24rem]" />
          </div>
        </Reveal>

        <Reveal delay={260}>
          <p className="mt-5 text-[13px] font-medium text-ink-3">
            Free and open source &middot; {site.minMacOS} or later &middot; about {site.size}
          </p>
        </Reveal>
      </div>

      <Reveal delay={120} className="px-6 pb-20 sm:pb-28">
        <div className="hidden md:block">
          <DesktopScene />
        </div>
        <div className="flex justify-center md:hidden">
          <LyricsWindow />
        </div>
      </Reveal>
    </section>
  );
}
