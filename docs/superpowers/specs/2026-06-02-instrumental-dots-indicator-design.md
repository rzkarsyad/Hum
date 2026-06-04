# Design: Instrumental Gap Timing Fix + Dots Indicator

**Date:** 2026-06-02
**Status:** Approved (design), pending implementation plan

## Problem

Hum renders synced karaoke lyrics from LRC files. Each LRC line has only a *start*
timestamp — there is no per-line *end* time. The current code infers a line's
duration as the time until the next line starts:

```swift
// KaraokeView.swift
private func lineDuration(for index: Int) -> TimeInterval {
    guard index + 1 < lines.count else { return 0.9 }
    let available = lines[index + 1].timestamp - lines[index].timestamp
    return max(available, 0.3)
}
```

This `available` value is used as the `totalDuration` of the per-character
appearance animation (`TextTransition` → `transaction.animation = .linear(duration:)`
in `TextEffects.swift`). The animation is therefore stretched across the entire span
until the next line.

**Bug:** When a line is followed by a long instrumental gap (e.g. 15s of music with
no lyrics), `available` becomes ~15s, so the characters of that line crawl in over
15 seconds — the line "slows down" (melambat) and feels out of sync. The line itself
started on time; only its animation pacing is wrong. The next line is correctly timed,
but the line before the gap mis-paces.

## Goals

1. **Fix the pacing bug:** a line's appearance animation should run at a natural
   singing pace, not stretch to fill an instrumental gap.
2. **Add an instrumental indicator:** during a sufficiently long instrumental gap
   (including a long intro before the first line), show a three-dot indicator whose
   fill progresses with the remaining gap time, giving the user a sense of "how long
   until the next lyric."

## Non-Goals

- Per-word/syllable karaoke timing (LRC line-level data does not support it).
- Changing the LRC parser, `LyricLine` model, or `MusicObserver`.
- Trailing/outro indicator after the final lyric.

## Approach: Synthetic Instrumental Items

Replace the flat `[LyricLine]` rendering with a unified item list that models
instrumental gaps as first-class items. This single change fixes the pacing bug AND
provides the structure for the dots indicator, reusing the existing scroll/centering/
opacity logic.

```swift
enum KaraokeItem: Equatable {
    case lyric(LyricLine)
    case instrumental(start: TimeInterval, end: TimeInterval)

    var start: TimeInterval {
        switch self {
        case .lyric(let l): return l.timestamp
        case .instrumental(let s, _): return s
        }
    }
}
```

### Building the item list

`buildItems(from lines: [LyricLine]) -> [KaraokeItem]`:

1. **Intro:** if `lines.first.timestamp >= GAP_THRESHOLD`, prepend
   `.instrumental(start: 0, end: lines.first.timestamp)`.
2. **Between lines:** for each line `i` with a successor, compute
   `lineEnd = lines[i].timestamp + naturalDuration(lines[i])`. If
   `lines[i+1].timestamp - lineEnd >= GAP_THRESHOLD`, append `.lyric(lines[i])` then
   `.instrumental(start: lineEnd, end: lines[i+1].timestamp)`; otherwise just append
   `.lyric(lines[i])`.
3. Always append the final `.lyric(lines.last)`.

Empty input → empty list.

### Why this fixes the bug

A lyric item's animation duration = `(next item's start) - (this item's start)`.

- Line followed by a long gap → next item is the instrumental, whose `start = lineEnd
  = timestamp + naturalDuration`. Duration = `naturalDuration` (clamped, natural pace).
- Line with no long gap → next item is the next lyric. Duration = gap to next line
  (identical to current behavior; normal lines are unaffected).

## Timing Math

```swift
// Tunable constants (initial values; adjust after manual testing)
let SEC_PER_CHAR: TimeInterval = 0.13
let MIN_LINE: TimeInterval     = 1.2
let MAX_LINE: TimeInterval     = 5.0
let GAP_THRESHOLD: TimeInterval = 5.0   // minimum gap to show the dots indicator

func naturalDuration(_ line: LyricLine) -> TimeInterval {
    let raw = Double(line.text.count) * SEC_PER_CHAR
    return min(max(raw, MIN_LINE), MAX_LINE)
}
```

Example: "Suatu hari kita berseru" (~23 chars) → ~3.0s, a plausible sung pace.

**Dots progress** (for the active instrumental item):

```swift
let progress = min(max((playbackPosition - start) / (end - start), 0), 1)
```

**Per-dot fill** (3 dots, sequential fill matching the reference image):

```swift
func fill(_ i: Int, progress: Double) -> Double {   // i in 0..<3
    min(max(progress * 3 - Double(i), 0), 1)
}
// dot 0 fills over progress 0–1/3, dot 1 over 1/3–2/3, dot 2 over 2/3–1
```

Each dot's opacity interpolates from a dim base to full bright based on
`fill(i, progress:)`.

## Active-Item Resolution

Generalize the existing binary search to operate on item start times:

```swift
func activeItemIndex(in items: [KaraokeItem], at position: TimeInterval) -> Int?
```

Returns the last item whose `start <= position` (nil if before the first item's
start). Behavior matches the current `activeIndex` but over the merged item list.

When the active item is `.instrumental`, the dots occupy the centered active slot;
the next lyric sits just below it (dim preview), and the just-sung lyric sits just
above (dim) — handled by the existing distance-based opacity and scroll-to-center.

## Dots View — 60fps Without Re-rendering KaraokeView

`KaraokeView` is wrapped in `.equatable()` so its body only re-evaluates when
`items`/`active`/`fontSize` change — this avoids re-rendering the whole scroll view
every frame. The dots, however, must update at 60fps to fill smoothly.

Solution: a small dedicated view that observes `MusicObserver` directly.

```swift
struct InstrumentalDotsView: View {
    let start: TimeInterval
    let end: TimeInterval
    @ObservedObject var clock: MusicObserver   // independent 60fps updates

    var body: some View {
        let progress = min(max((clock.playbackPosition - start) / (end - start), 0), 1)
        // render 3 dots, each opacity driven by fill(i)
    }
}
```

Because `InstrumentalDotsView` holds its own `@ObservedObject` subscription, SwiftUI
updates only this subview when `playbackPosition` ticks — `KaraokeView.body` does not
re-run. `KaraokeView` receives `musicObserver` solely to forward it into this subview;
its `==` continues to compare only `items`, `active`, and `fontSize` (the observer is
excluded from equality).

`MusicObserver` already publishes `playbackPosition` at 60fps via its `displayTimer`
(`MusicObserver.swift:31`), and `HumWindowView` already re-renders at that rate, so no
new timer is needed.

## Files

**New**
- `Hum/Views/KaraokeItem.swift` — `KaraokeItem` enum, `buildItems(from:)`,
  `naturalDuration(_:)`, `fill(_:progress:)` helper, tunable constants.
- `Hum/Views/InstrumentalDotsView.swift` — the dots view.

**Changed**
- `Hum/Views/KaraokeView.swift` — render `[KaraokeItem]` instead of `[LyricLine]`;
  `lineDuration` derives from the next item's start; render `InstrumentalDotsView` for
  instrumental items; accept and forward `musicObserver`; `activeIndex` →
  `activeItemIndex`.
- `Hum/Views/HumWindowView.swift` — build items from `lyricsState.lines`, compute the
  active item index from `playbackPosition`, pass items + `musicObserver` to
  `KaraokeView`.

**Unchanged**
- `LRCParser.swift`, `LyricLine`, `MusicObserver.swift`.

## Testing (XCTest, matching existing patterns)

- `buildItems`:
  - inserts an intro instrumental when the first line starts after the threshold;
  - inserts an instrumental between two lines when the post-`naturalDuration` gap
    meets the threshold;
  - does NOT insert when the gap is below threshold;
  - empty input → empty output; single line → single lyric item, no trailing item.
- `naturalDuration`: clamps to `[MIN_LINE, MAX_LINE]`; scales with character count
  in between.
- `fill(_:progress:)`: correct sequential fill at progress 0, 1/6, 1/3, 1/2, 1.0.
- `activeItemIndex`: returns the instrumental item when the position lies inside a
  gap; returns the correct lyric item otherwise; nil before the first item.

## Build Note

New Swift files require `xcodegen generate` before `xcodebuild` so they are registered
in the pbxproj (per project convention).
