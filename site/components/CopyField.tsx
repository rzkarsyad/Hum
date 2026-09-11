"use client";

import { useEffect, useState } from "react";

export function CopyField({
  value,
  label,
  multiline = false,
  className = "",
}: {
  value: string;
  label?: string;
  /** Wrap the command onto a second line instead of truncating it. */
  multiline?: boolean;
  className?: string;
}) {
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!copied) return;
    const id = setTimeout(() => setCopied(false), 1800);
    return () => clearTimeout(id);
  }, [copied]);

  async function copy() {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
    } catch {
      // Clipboard blocked (insecure context, denied permission) — leave the
      // command on screen so it can still be selected by hand.
    }
  }

  return (
    <button
      type="button"
      onClick={copy}
      aria-label={`Copy ${label ?? "command"} to clipboard`}
      className={`group flex w-full items-center gap-3 rounded-2xl border border-hairline bg-white px-4 py-3 text-left shadow-[0_1px_2px_rgba(9,9,16,0.04)] transition hover:border-brand/30 hover:shadow-[0_8px_24px_-12px_rgba(10,132,255,0.35)] ${className}`}
    >
      <code
        className={`min-w-0 flex-1 font-code text-[13px] text-ink-2 ${
          multiline ? "break-words" : "truncate"
        }`}
      >
        {value}
      </code>
      <span
        className={`shrink-0 rounded-full px-2.5 py-1 text-xs font-semibold transition ${
          copied ? "bg-brand/10 text-brand" : "bg-paper-2 text-ink-3 group-hover:text-ink-2"
        }`}
      >
        {copied ? "Copied" : "Copy"}
      </span>
    </button>
  );
}
