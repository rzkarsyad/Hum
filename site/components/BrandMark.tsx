import { brandIcons } from "@/lib/icons";

/**
 * A logo, drawn monochrome so the row reads as one set. Edge has no Simple
 * Icons mark, so it gets a neutral globe rather than a wrong logo.
 */
export function BrandMark({
  name,
  className = "size-6",
}: {
  name: string;
  className?: string;
}) {
  if (name === "edge") {
    return (
      <svg
        viewBox="0 0 24 24"
        className={className}
        fill="none"
        stroke="currentColor"
        strokeWidth="1.7"
        aria-hidden="true"
      >
        <circle cx="12" cy="12" r="10.2" />
        <ellipse cx="12" cy="12" rx="4.3" ry="10.2" />
        <path d="M2.3 8.7h19.4M2.3 15.3h19.4" />
      </svg>
    );
  }

  const icon = brandIcons[name as keyof typeof brandIcons];
  if (!icon) return null;

  return (
    <svg viewBox="0 0 24 24" className={className} fill="currentColor" aria-hidden="true">
      <path d={icon.path} />
    </svg>
  );
}
