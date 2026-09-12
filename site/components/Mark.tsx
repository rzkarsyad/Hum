import Image from "next/image";

/**
 * The Hum mark: the real app icon, copied from
 * Hum/Assets.xcassets/AppIcon.appiconset/icon_256.png.
 * Re-copy that file to public/hum-icon.png whenever the app icon changes.
 */
export function Mark({ className = "size-8" }: { className?: string }) {
  return (
    <Image
      src="/hum-icon.png"
      alt=""
      width={256}
      height={256}
      priority
      className={`shrink-0 rounded-[22%] ${className}`}
    />
  );
}
