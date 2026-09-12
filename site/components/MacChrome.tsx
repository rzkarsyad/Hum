import Image from "next/image";

/**
 * macOS menu bar and Dock, rebuilt for the hero scene.
 *
 * The Dock icons are the real ones, rendered from the .icns files inside each
 * app bundle on macOS 27 and converted to WebP. See site/README.md for the
 * extraction script. Everything else here is drawn.
 */

const MENUS = ["Finder", "File", "Edit", "View", "Go", "Window", "Help"];

const DOCK = [
  "finder", "apps", "safari", "messages", "mail", "maps", "photos", "facetime",
  "calendar", "contacts", "reminders", "notes", "freeform", "tv", "music",
  "news", "appstore",
] as const;

const LABELS: Record<string, string> = {
  finder: "Finder", apps: "Apps", safari: "Safari", messages: "Messages",
  mail: "Mail", maps: "Maps", photos: "Photos", facetime: "FaceTime",
  calendar: "Calendar", contacts: "Contacts", reminders: "Reminders",
  notes: "Notes", freeform: "Freeform", tv: "TV", music: "Music",
  news: "News", appstore: "App Store", downloads: "Downloads", trash: "Trash",
};

function DockIcon({ name, running = false }: { name: string; running?: boolean }) {
  return (
    <div className="relative min-w-0 flex-1">
      <div className="aspect-square">
        <Image
          src={`/dock/${name}.webp`}
          alt={LABELS[name] ?? name}
          width={128}
          height={128}
          className="size-full object-contain"
        />
      </div>
      {running && (
        <span
          className="absolute inset-x-0 -bottom-[3px] mx-auto size-[2.5px] rounded-full bg-black/55"
          aria-hidden="true"
        />
      )}
    </div>
  );
}

export function MenuBar() {
  return (
    <div className="relative flex h-[3.35%] items-center gap-2 bg-white/20 px-2.5 text-[9px] leading-none font-medium text-black/80 backdrop-blur-xl sm:px-3">
      <svg viewBox="0 0 24 24" className="size-[9px] shrink-0" fill="currentColor" aria-hidden="true">
        <path d="M16.4 12.7c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.2-2.8.9-3.5.9s-1.8-.8-3-.8c-1.5 0-3 .9-3.8 2.3-1.6 2.8-.4 7 1.2 9.3.8 1.1 1.7 2.4 2.9 2.3 1.2 0 1.6-.7 3-.7s1.8.7 3 .7 2-1.1 2.8-2.2c.9-1.3 1.2-2.5 1.3-2.6-.1 0-2.5-1-2.5-3.9ZM14.2 5.6c.6-.8 1.1-1.9 1-3-1 0-2.2.7-2.9 1.5-.6.7-1.2 1.8-1 2.9 1.1 0 2.2-.6 2.9-1.4Z" />
      </svg>

      <span className="hidden items-center gap-2.5 sm:flex">
        {MENUS.map((m, i) => (
          <span key={m} className={i === 0 ? "font-bold" : "font-medium"}>
            {m}
          </span>
        ))}
      </span>

      <span className="ml-auto flex items-center gap-2">
        {/* Hum, sitting where it actually lives */}
        <span className="relative grid place-items-center">
          <span className="absolute -inset-[3px] rounded-[4px] bg-white/60" aria-hidden="true" />
          <svg viewBox="0 0 24 24" className="relative size-[9px]" fill="currentColor" aria-hidden="true">
            <path d="M20 3.5v11.2a3.3 3.3 0 1 1-1.8-2.94V6.6l-7.4 1.68v8.77a3.3 3.3 0 1 1-1.8-2.94V6.02L20 3.5Z" />
          </svg>
        </span>

        {/* Wi-Fi */}
        <svg viewBox="0 0 24 20" className="size-[9px]" fill="currentColor" aria-hidden="true">
          <path d="M12 17.2a1.9 1.9 0 1 0 0-3.8 1.9 1.9 0 0 0 0 3.8Z" />
          <path d="M12 9.6c1.9 0 3.6.7 4.9 1.9l1.6-1.7A9.6 9.6 0 0 0 12 7.2a9.6 9.6 0 0 0-6.5 2.6l1.6 1.7A7.1 7.1 0 0 1 12 9.6Z" />
          <path d="M12 4.6c3.2 0 6.2 1.2 8.4 3.2l1.6-1.7A14.6 14.6 0 0 0 12 2.2 14.6 14.6 0 0 0 2 6.1l1.6 1.7A12.4 12.4 0 0 1 12 4.6Z" />
        </svg>

        {/* Search */}
        <svg viewBox="0 0 24 24" className="size-[9px]" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" aria-hidden="true">
          <circle cx="10.5" cy="10.5" r="6.5" />
          <path d="M15.5 15.5 21 21" />
        </svg>

        {/* Account */}
        <svg viewBox="0 0 24 24" className="size-[9px]" fill="none" stroke="currentColor" strokeWidth="1.9" aria-hidden="true">
          <circle cx="12" cy="12" r="9.2" />
          <circle cx="12" cy="9.6" r="3.2" />
          <path d="M5.9 19.4a6.6 6.6 0 0 1 12.2 0" />
        </svg>

        {/* Control Centre */}
        <svg viewBox="0 0 24 24" className="size-[9px]" fill="currentColor" aria-hidden="true">
          <path d="M4 6.2h16v3.1H4zM4 14.7h16v3.1H4z" opacity="0.35" />
          <circle cx="15" cy="7.75" r="2.5" />
          <circle cx="9" cy="16.25" r="2.5" />
        </svg>

        <span className="tabular-nums">Mon Jun 10&nbsp;&nbsp;9:41 AM</span>
      </span>
    </div>
  );
}

export function Dock() {
  return (
    <div className="pointer-events-none absolute inset-x-0 bottom-0 flex justify-center pb-[1.4%]">
      <div className="flex w-[64%] items-end gap-[0.5%] rounded-[14px] border border-white/50 bg-white/25 px-[0.55%] pt-[0.55%] pb-[0.9%] shadow-[0_8px_24px_-8px_rgba(9,9,16,0.35)] backdrop-blur-xl sm:rounded-[16px]">
        {DOCK.map((name) => (
          <DockIcon key={name} name={name} running={name === "finder" || name === "music"} />
        ))}
        <div className="mx-[0.6%] w-px self-stretch bg-black/15" aria-hidden="true" />
        <DockIcon name="downloads" />
        <DockIcon name="trash" />
      </div>
    </div>
  );
}
