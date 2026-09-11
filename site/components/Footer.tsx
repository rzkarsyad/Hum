import { Mark } from "@/components/Mark";
import { site } from "@/lib/site";

const columns = [
  {
    title: "Get Hum",
    links: [
      { label: "Download", href: "#install" },
      { label: "Releases", href: site.releases },
      { label: "Changelog", href: site.changelog },
    ],
  },
  {
    title: "Project",
    links: [
      { label: "Source on GitHub", href: site.repo },
      { label: "Report an issue", href: site.issues },
      { label: "Privacy policy", href: site.privacy },
    ],
  },
  {
    title: "Thanks to",
    links: [
      { label: "LRCLIB", href: "https://lrclib.net" },
      { label: "mediaremote-adapter", href: "https://github.com/ungive/mediaremote-adapter" },
    ],
  },
];

export function Footer() {
  return (
    <footer className="border-t border-hairline bg-paper-2/50">
      <div className="mx-auto max-w-6xl px-6 py-16">
        <div className="grid gap-12 sm:grid-cols-2 lg:grid-cols-[1.4fr_repeat(3,1fr)]">
          <div>
            <div className="flex items-center gap-2.5">
              <Mark className="size-7" />
              <span className="text-[17px] font-extrabold tracking-[-0.02em]">Hum</span>
            </div>
            <p className="mt-4 max-w-[26ch] text-[15px] leading-relaxed text-ink-3">
              Made for people who mumble the second verse.
            </p>
          </div>

          {columns.map((column) => (
            <div key={column.title}>
              <h3 className="text-[13px] font-bold tracking-wide text-ink-3 uppercase">
                {column.title}
              </h3>
              <ul className="mt-4 space-y-2.5">
                {column.links.map((link) => (
                  <li key={link.label}>
                    <a
                      href={link.href}
                      target={link.href.startsWith("#") ? undefined : "_blank"}
                      rel={link.href.startsWith("#") ? undefined : "noreferrer"}
                      className="text-[15px] font-medium text-ink-2 transition hover:text-brand"
                    >
                      {link.label}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <div className="mt-14 flex flex-col gap-2 border-t border-hairline pt-7 text-[13px] text-ink-3 sm:flex-row sm:items-center sm:justify-between">
          <p>MIT licensed. Not affiliated with Apple or Spotify.</p>
          <p>Lyrics provided by LRCLIB.</p>
        </div>
      </div>
    </footer>
  );
}
