import { site } from "@/lib/site";

const links = [
  { label: "GitHub", href: site.repo },
  { label: "Changelog", href: site.changelog },
  { label: "Privacy", href: site.privacy },
  { label: "Support", href: site.issues },
];

export function Footer() {
  return (
    <footer className="mx-auto max-w-[600px] px-6 pb-16">
      <div className="flex flex-col gap-3 border-t border-hairline pt-6 text-[12.5px] text-ink-3 sm:flex-row sm:items-center sm:justify-between">
        <p>&copy; 2026 Hum &middot; MIT licensed</p>
        <ul className="flex flex-wrap items-center gap-x-5 gap-y-2">
          {links.map((link) => (
            <li key={link.label}>
              <a
                href={link.href}
                target="_blank"
                rel="noreferrer"
                className="transition hover:text-ink"
              >
                {link.label}
              </a>
            </li>
          ))}
        </ul>
      </div>
    </footer>
  );
}
