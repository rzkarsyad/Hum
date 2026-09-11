import { Reveal } from "@/components/Reveal";

const players = ["Apple Music", "Spotify", "YouTube Music"];
const browsers = ["Safari", "Chrome", "Arc", "Brave", "Edge", "Firefox"];

export function Sources() {
  return (
    <section className="border-y border-hairline bg-white/60">
      <div className="mx-auto max-w-5xl px-6 py-14 text-center">
        <Reveal>
          <p className="text-[13px] font-bold tracking-[0.12em] text-ink-3 uppercase">
            Works with whatever is already playing
          </p>
        </Reveal>
        <Reveal delay={80}>
          <ul className="mt-6 flex flex-wrap items-center justify-center gap-2.5">
            {players.map((name) => (
              <li
                key={name}
                className="rounded-full border border-hairline bg-white px-4 py-2 text-[15px] font-bold text-ink shadow-[0_1px_2px_rgba(9,9,16,0.04)]"
              >
                {name}
              </li>
            ))}
          </ul>
        </Reveal>
        <Reveal delay={140}>
          <ul className="mt-3 flex flex-wrap items-center justify-center gap-2">
            {browsers.map((name) => (
              <li
                key={name}
                className="rounded-full bg-paper-2 px-3.5 py-1.5 text-[14px] font-semibold text-ink-2"
              >
                {name}
              </li>
            ))}
          </ul>
        </Reveal>
        <Reveal delay={200}>
          <p className="mx-auto mt-7 max-w-[52ch] text-[15px] leading-relaxed text-ink-3">
            Apple Music and Spotify are read directly. Browser playback comes through
            the macOS Now Playing system, so a music video in any tab gets lyrics too.
          </p>
        </Reveal>
      </div>
    </section>
  );
}
