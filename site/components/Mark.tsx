/** The Hum mark — the note from the app icon, on its blue tile. */
export function Mark({ className = "size-8" }: { className?: string }) {
  return (
    <span
      className={`relative inline-grid shrink-0 place-items-center overflow-hidden rounded-[28%] bg-brand ${className}`}
      aria-hidden="true"
    >
      <svg viewBox="0 0 24 24" className="size-[62%] text-white" fill="currentColor">
        <path d="M20 3.5v11.2a3.3 3.3 0 1 1-1.8-2.94V6.6l-7.4 1.68v8.77a3.3 3.3 0 1 1-1.8-2.94V6.02L20 3.5Z" />
      </svg>
    </span>
  );
}
