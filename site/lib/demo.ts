/**
 * The demo track that drives the hero window.
 *
 * The lyrics are original filler written for this page, never real song
 * lyrics, so the site carries no licensing baggage.
 *
 * Shape mirrors KaraokeItem in Hum/Views/KaraokeItem.swift: a flat list of
 * sung lines with `instrumental` items filling the gaps between them.
 */
export type DemoItem =
  | { kind: "lyric"; start: number; text: string }
  | { kind: "instrumental"; start: number; end: number };

export const DEMO_TRACK = {
  title: "Right on Time",
  artist: "Hum Sample",
};

export const DEMO_ITEMS: DemoItem[] = [
  { kind: "instrumental", start: 0, end: 3.6 },
  { kind: "lyric", start: 3.6, text: "I hear it start, a quiet hum" },
  { kind: "lyric", start: 7.0, text: "somewhere between the dark and dawn" },
  { kind: "lyric", start: 10.6, text: "and every word you sing along" },
  { kind: "lyric", start: 14.0, text: "lands right on time" },
  { kind: "instrumental", start: 16.6, end: 20.4 },
  { kind: "lyric", start: 20.4, text: "so turn it up and let it run" },
  { kind: "lyric", start: 23.8, text: "we're only halfway through the song" },
];

/** Loop length in seconds, with a beat of breathing room after the last line. */
export const DEMO_LOOP = 28;

/** The moment shown when motion is switched off. */
export const DEMO_STILL = 12.4;

/** Start of the item at `index`, or the loop end for the item past the last. */
function startOf(index: number): number {
  const item = DEMO_ITEMS[index];
  return item ? item.start : DEMO_LOOP;
}

/** Index of the item playing at time `t`. Mirrors `activeItemIndex`. */
export function activeItemIndex(t: number): number {
  let active = 0;
  for (let i = 0; i < DEMO_ITEMS.length; i++) {
    if (DEMO_ITEMS[i].start <= t) active = i;
    else break;
  }
  return active;
}

/**
 * How long item `index` has before the next one begins: the window the
 * character reveal is spread across. Mirrors `lineDuration(for:)`.
 */
export function itemDuration(index: number): number {
  return Math.max(startOf(index + 1) - startOf(index), 0.3);
}

/** Dot `i` fills over the middle third of the gap. Mirrors `dotFill`. */
export function dotFill(i: number, progress: number): number {
  return Math.min(Math.max(progress * 3 - i, 0), 1);
}
