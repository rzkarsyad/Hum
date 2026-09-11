import { Reveal } from "@/components/Reveal";

function Card({
  span = "",
  children,
}: {
  span?: string;
  children: React.ReactNode;
}) {
  return (
    <div
      className={`flex flex-col rounded-[26px] border border-hairline bg-white p-7 shadow-[0_1px_2px_rgba(9,9,16,0.04)] transition duration-500 hover:shadow-[0_18px_40px_-24px_rgba(9,9,16,0.22)] ${span}`}
    >
      {children}
    </div>
  );
}

function Title({ children }: { children: React.ReactNode }) {
  return (
    <h3 className="text-[20px] font-extrabold tracking-[-0.02em] text-ink">{children}</h3>
  );
}

function Body({ children }: { children: React.ReactNode }) {
  return (
    <p className="mt-2.5 text-[15px] leading-[1.6] font-medium text-ink-2">{children}</p>
  );
}

/** Static echo of the karaoke reveal: sung glyphs bright, the rest still dim. */
function KaraokePreview() {
  const line = "and every word you sing along";
  const sung = Math.round(line.length * 0.55);
  return (
    <div className="mt-7 overflow-hidden rounded-2xl bg-[#16161b] p-5 ring-1 ring-black/5">
      <p className="text-[13px] font-bold whitespace-pre text-white/25">
        somewhere between the dark and dawn
      </p>
      <p className="mt-2 text-[15px] font-bold whitespace-pre">
        <span className="text-white">{line.slice(0, sung)}</span>
        <span className="text-white/30">{line.slice(sung)}</span>
      </p>
      <p className="mt-2 text-[13px] font-bold whitespace-pre text-white/20">
        lands right on time
      </p>
    </div>
  );
}

function DotsPreview() {
  return (
    <div className="mt-7 flex items-center gap-2 rounded-2xl bg-[#16161b] px-5 py-6 ring-1 ring-black/5">
      {[1, 0.55, 0].map((fill, i) => (
        <span
          key={i}
          className="size-2 rounded-full bg-white"
          style={{ opacity: 0.25 + 0.75 * fill }}
        />
      ))}
    </div>
  );
}

export function Features() {
  return (
    <section id="features" className="mx-auto max-w-6xl px-6 py-24 sm:py-32">
      <Reveal>
        <h2 className="headline max-w-[18ch] text-[clamp(2rem,4.4vw,3.25rem)]">
          Small app. Considered
          <span className="text-ink-3"> down to the frame.</span>
        </h2>
      </Reveal>

      <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <Reveal className="lg:col-span-2">
          <Card span="h-full">
            <Title>Every word lights up as it&rsquo;s sung</Title>
            <Body>
              Lyrics arrive from LRCLIB already timestamped. Each glyph eases in from
              a soft blur exactly when you&rsquo;d sing it, while the lines either side
              fall gently out of focus. The active line always sits dead centre.
            </Body>
            <KaraokePreview />
          </Card>
        </Reveal>

        <Reveal delay={70}>
          <Card span="h-full">
            <Title>Always on top</Title>
            <Body>
              Above every window, across every Space, over fullscreen apps. Hum stays
              exactly where you put it &mdash; and remembers the spot next launch.
            </Body>
          </Card>
        </Reveal>

        <Reveal delay={40}>
          <Card span="h-full">
            <Title>Dots for the quiet parts</Title>
            <Body>
              Intros, solos and long gaps get three dots that fill as the music runs,
              so you always know where you are.
            </Body>
            <DotsPreview />
          </Card>
        </Reveal>

        <Reveal delay={100}>
          <Card span="h-full">
            <Title>Yours to move</Title>
            <Body>
              Drag it anywhere, resize it, dial the type up or down, or collapse it to
              a slim bar when you just want the track name. Hide it and it stays hidden
              until you say otherwise.
            </Body>
          </Card>
        </Reveal>

        <Reveal delay={160}>
          <Card span="h-full">
            <Title>Starts when you do</Title>
            <Body>
              Turn on launch at login and Hum is simply there: one note in the menu bar,
              no Dock icon, nothing in the way.
            </Body>
          </Card>
        </Reveal>

        <Reveal className="lg:col-span-3" delay={60}>
          <Card>
            <div className="flex flex-col gap-6 sm:flex-row sm:items-center sm:justify-between">
              <div className="max-w-[52ch]">
                <Title>Native Swift, about 2.5 MB</Title>
                <Body>
                  No Electron, no bundled browser, no runtime to install. Hum polls
                  playback in the background and interpolates position at 60fps, so the
                  lyrics stay in step without heating up your Mac.
                </Body>
              </div>
              <div className="flex shrink-0 gap-8">
                {[
                  { value: "2.5", unit: "MB", label: "on disk" },
                  { value: "60", unit: "fps", label: "sync" },
                  { value: "0", unit: "", label: "trackers" },
                ].map((stat) => (
                  <div key={stat.label}>
                    <p className="text-[32px] leading-none font-extrabold tracking-[-0.03em] text-ink">
                      {stat.value}
                      <span className="text-[18px] text-ink-3">{stat.unit}</span>
                    </p>
                    <p className="mt-1.5 text-[13px] font-semibold text-ink-3">{stat.label}</p>
                  </div>
                ))}
              </div>
            </div>
          </Card>
        </Reveal>
      </div>
    </section>
  );
}
