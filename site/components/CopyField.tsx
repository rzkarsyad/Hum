"use client";

import { useEffect, useState } from "react";

export function CopyField({
  value,
  label,
  multiline = false,
  tone = "raised",
  className = "",
}: {
  value: string;
  label?: string;
  /** Wrap the command onto a second line instead of truncating it. */
  multiline?: boolean;
  /** "raised" sits white on the grey page; "inset" sits grey inside a white card. */
  tone?: "raised" | "inset";
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
      // Clipboard blocked (insecure context, denied permission), so leave the
      // command on screen so it can still be selected by hand.
    }
  }

  return (
    <button
      type="button"
      onClick={copy}
      aria-label={`Copy ${label ?? "command"} to clipboard`}
      className={`group flex w-full items-center gap-3 rounded-2xl border px-4 py-3 text-left transition hover:border-brand/40 ${
        tone === "inset" ? "border-transparent bg-paper" : "border-hairline bg-white"
      } ${className}`}
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
          copied
            ? "bg-brand/10 text-brand"
            : tone === "inset"
              ? "bg-white text-ink-3 group-hover:text-ink-2"
              : "bg-paper-2 text-ink-3 group-hover:text-ink-2"
        }`}
      >
        {copied ? "Copied" : "Copy"}
      </span>
    </button>
  );
}
