import { CopyField } from "@/components/CopyField";
import { Reveal } from "@/components/Reveal";
import { site } from "@/lib/site";

export function Install() {
  return (
    <section id="install" className="border-t border-hairline bg-paper-2/60">
      <div className="mx-auto max-w-5xl px-6 py-24 sm:py-32">
        <Reveal>
          <h2 className="headline max-w-[16ch] text-[clamp(2rem,4.4vw,3.25rem)]">
            Two minutes, then never think about it again.
          </h2>
        </Reveal>

        <div className="mt-12 grid gap-4 lg:grid-cols-2">
          <Reveal>
            <div className="flex h-full flex-col rounded-[26px] border border-hairline bg-white p-7">
              <div className="flex items-center gap-2.5">
                <h3 className="text-[20px] font-extrabold tracking-[-0.02em]">Homebrew</h3>
                <span className="rounded-full bg-brand/10 px-2.5 py-0.5 text-[12px] font-bold text-brand">
                  Recommended
                </span>
              </div>
              <p className="mt-2.5 text-[15px] leading-[1.6] font-medium text-ink-2">
                One command, and updates come along with the rest of your casks.
              </p>
              <div className="mt-auto pt-6">
                <CopyField value={site.brew} label="the Homebrew command" multiline />
              </div>
            </div>
          </Reveal>

          <Reveal delay={80}>
            <div className="flex h-full flex-col rounded-[26px] border border-hairline bg-white p-7">
              <h3 className="text-[20px] font-extrabold tracking-[-0.02em]">Direct download</h3>
              <p className="mt-2.5 text-[15px] leading-[1.6] font-medium text-ink-2">
                Grab the <code className="font-code text-[14px] text-ink">.dmg</code>, open it,
                drag Hum to Applications. Built-in updates handle the rest.
              </p>
              <div className="mt-auto pt-6">
                <a
                  href={site.releases}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex w-full items-center justify-center gap-2 rounded-full bg-ink px-5 py-3.5 text-[15px] font-bold text-white transition hover:bg-ink/85"
                >
                  Download Hum {site.version}
                  <span aria-hidden="true">&darr;</span>
                </a>
              </div>
            </div>
          </Reveal>
        </div>

        <Reveal delay={140}>
          <div className="mt-4 rounded-[26px] border border-hairline bg-white/70 p-7">
            <h3 className="text-[15px] font-extrabold tracking-[-0.01em]">
              One thing macOS will ask about
            </h3>
            <p className="mt-2 max-w-[70ch] text-[15px] leading-[1.6] font-medium text-ink-2">
              Hum isn&rsquo;t notarised by Apple yet, so Gatekeeper may block it on first
              open. The <code className="font-code text-[14px] text-ink">--no-quarantine</code>{" "}
              flag takes care of that for Homebrew. If you used the{" "}
              <code className="font-code text-[14px] text-ink">.dmg</code>, open{" "}
              <span className="font-semibold text-ink">
                System Settings &rsaquo; Privacy &amp; Security
              </span>{" "}
              and choose <span className="font-semibold text-ink">Open Anyway</span>. You&rsquo;ll
              also see a one-time prompt for Automation access, which is how Hum reads the
              track you&rsquo;re playing.
            </p>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
