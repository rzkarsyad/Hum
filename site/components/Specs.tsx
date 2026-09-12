import type { ReactNode } from "react";
import { CopyField } from "@/components/CopyField";
import { Reveal } from "@/components/Reveal";
import { site } from "@/lib/site";

function Card({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="overflow-hidden rounded-2xl bg-white">
      <p className="px-5 pt-6 pb-2 text-[11px] font-bold tracking-[0.1em] text-ink-3 uppercase">
        {label}
      </p>
      <dl className="divide-y divide-hairline px-5">{children}</dl>
    </div>
  );
}

function Row({ term, children }: { term: string; children: ReactNode }) {
  return (
    <div className="grid gap-1.5 py-[18px] sm:grid-cols-[116px_1fr] sm:gap-6">
      <dt className="text-[13.5px] leading-[1.75] font-bold text-ink">{term}</dt>
      <dd className="text-[13.5px] leading-[1.75] text-ink-2">{children}</dd>
    </div>
  );
}

export function Specs() {
  return (
    <section id="features" className="mx-auto max-w-[600px] space-y-3 px-6 pb-20">
      <Reveal>
        <Card label="How it works">
          <Row term="Synced lyrics">
            Timestamped lines from LRCLIB, matched to the playing track by title,
            artist and duration.
          </Row>
          <Row term="Always on top">
            Floats above every window, across every Space, over fullscreen apps.
          </Row>
          <Row term="Karaoke reveal">
            Each word lights up as it&rsquo;s sung. The lines around it fall out of
            focus, and the active one stays centred.
          </Row>
          <Row term="Instrumental dots">
            Three dots fill through intros, solos and any gap longer than five
            seconds, so you always know where you are.
          </Row>
          <Row term="Yours to arrange">
            Drag it, resize it, change the type size, or collapse it to a slim bar.
            It remembers where you left it.
          </Row>
          <Row term="Menu bar">
            Lives quietly in the menu bar. No Dock icon. Hide it with one click; it
            stays hidden until you say otherwise.
          </Row>
        </Card>
      </Reveal>

      <Reveal>
        <Card label="Install">
          <Row term="Homebrew">
            <CopyField value={site.brew} label="the Homebrew command" multiline tone="inset" />
          </Row>
          <Row term="Direct">
            <a
              href={site.releases}
              target="_blank"
              rel="noreferrer"
              className="font-semibold text-brand transition hover:text-brand-3"
            >
              Download the DMG
            </a>
            , open it, drag Hum to Applications. Updates arrive in the app.
          </Row>
          <Row term="Signed">
            Signed with a Developer ID certificate and notarised by Apple, so macOS
            opens it without a warning.
          </Row>
        </Card>
      </Reveal>

      <Reveal>
        <Card label="Requirements">
          <Row term="macOS">15 Sequoia or later.</Row>
          <Row term="Players">
            Apple Music, Spotify, or music playing in a supported browser.
          </Row>
          <Row term="Permissions">
            Automation, so Hum can read the track you&rsquo;re playing. macOS asks
            once.
          </Row>
          <Row term="Size">
            About {site.size}. Native Swift and SwiftUI, no Electron, no runtime to
            install.
          </Row>
        </Card>
      </Reveal>

      <Reveal>
        <Card label="Private by design">
          <Row term="On device">
            Playback position and artwork are read, drawn, and forgotten. Nothing is
            recorded or uploaded.
          </Row>
          <Row term="One request">
            The title and artist of the current track go to LRCLIB to fetch its
            lyrics. Nothing else leaves your Mac.
          </Row>
          <Row term="No account">
            Free and open source under MIT. No sign-up, no analytics, no telemetry,
            no crash reporting.
          </Row>
        </Card>
      </Reveal>
    </section>
  );
}
