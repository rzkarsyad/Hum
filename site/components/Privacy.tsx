import { Reveal } from "@/components/Reveal";
import { site } from "@/lib/site";

const points = [
  {
    title: "No account, ever",
    body: "There is nothing to sign up for and nothing to sign in to. Hum has no idea who you are.",
  },
  {
    title: "No analytics, no telemetry",
    body: "No crash reporting, no usage pings, no third-party SDKs. Nothing is counted, because nothing is sent.",
  },
  {
    title: "Exactly one outbound request",
    body: "The title and artist of the current track go to LRCLIB to fetch its lyrics. That is the only thing that leaves your Mac.",
  },
];

export function Privacy() {
  return (
    <section id="privacy" className="mx-auto max-w-6xl px-6 py-24 sm:py-32">
      <div className="grid gap-12 lg:grid-cols-[1fr_1.15fr] lg:items-start lg:gap-20">
        <Reveal>
          <h2 className="headline max-w-[14ch] text-[clamp(2rem,4.4vw,3.25rem)]">
            Hum doesn&rsquo;t want to know anything about you.
          </h2>
          <p className="mt-6 max-w-[46ch] text-[17px] leading-[1.55] font-medium text-ink-2">
            Your listening history isn&rsquo;t a product here. Playback position and artwork
            are read, used to draw a window, and forgotten.
          </p>
          <a
            href={site.privacy}
            target="_blank"
            rel="noreferrer"
            className="mt-7 inline-flex items-center gap-2 text-[15px] font-bold text-brand transition hover:text-brand-3"
          >
            Read the privacy policy
            <span aria-hidden="true">&rarr;</span>
          </a>
        </Reveal>

        <Reveal delay={100}>
          <ul className="divide-y divide-hairline overflow-hidden rounded-[26px] border border-hairline bg-white">
            {points.map((point) => (
              <li key={point.title} className="p-7">
                <h3 className="text-[17px] font-extrabold tracking-[-0.02em]">{point.title}</h3>
                <p className="mt-2 text-[15px] leading-[1.6] font-medium text-ink-2">{point.body}</p>
              </li>
            ))}
          </ul>
        </Reveal>
      </div>
    </section>
  );
}
