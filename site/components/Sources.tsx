import { BrandMark } from "@/components/BrandMark";
import { Reveal } from "@/components/Reveal";
import { BROWSERS, PLAYERS } from "@/lib/icons";

function Tile({
  name,
  label,
  size,
}: {
  name: string;
  label: string;
  size: "lg" | "sm";
}) {
  return (
    <div className="flex h-full flex-col items-center justify-center gap-2 rounded-2xl bg-white px-2 py-4">
      <BrandMark
        name={name}
        className={`${size === "lg" ? "size-7" : "size-5"} text-ink/75`}
      />
      <span
        className={`text-center font-semibold text-ink-2 ${
          size === "lg" ? "text-[13px]" : "text-[11.5px]"
        }`}
      >
        {label}
      </span>
    </div>
  );
}

export function Sources() {
  return (
    <section className="mx-auto max-w-[600px] px-6 pb-20">
      <Reveal>
        <p className="text-center text-[11px] font-bold tracking-[0.1em] text-ink-3 uppercase">
          Works with whatever is already playing
        </p>
      </Reveal>

      <Reveal delay={60}>
        <ul className="mt-5 grid grid-cols-3 gap-2">
          {PLAYERS.map((p) => (
            <li key={p.key}>
              <Tile name={p.key} label={p.label} size="lg" />
            </li>
          ))}
        </ul>
      </Reveal>

      <Reveal delay={110}>
        <ul className="mt-2 grid grid-cols-3 gap-2 sm:grid-cols-6">
          {BROWSERS.map((b) => (
            <li key={b.key}>
              <Tile name={b.key} label={b.label} size="sm" />
            </li>
          ))}
        </ul>
      </Reveal>

      <Reveal delay={160}>
        <p className="mt-6 text-center text-[13.5px] leading-[1.75] text-pretty text-ink-3">
          Apple Music and Spotify are read directly. Browser playback comes through
          the macOS Now Playing system, so a music video in any tab gets lyrics too.
        </p>
      </Reveal>
    </section>
  );
}
