# Hum — UI Improvements: Design Spec

**Date:** 2026-05-03

---

## Overview

Four improvements to the Hum floating lyrics window:
1. Better word timing via character-weighted interpolation with 10% start/end buffer
2. Uniform font size across all lyric lines
3. Song title header at the top of the window
4. Manual hide button with status bar toggle to restore

---

## 1. Timing — Character-weighted + 10% Buffer

**Changes:** `Hum/Models/WordToken.swift`, `HumTests/WordTokenTests.swift`

Replace the even-distribution formula with character-weighted distribution plus a 10% buffer at the start and end of each line:

```
effective_duration = duration × 0.8
start_offset       = duration × 0.1

total_chars = sum of word.count for all words in line
cumulative_chars[i] = sum of word[j].count for j < i

word[i].timestamp = line.timestamp
                  + start_offset
                  + (cumulative_chars[i] / total_chars) × effective_duration
```

**Why:** The 10% buffer at the start accounts for the musical intro before the first word is sung; the 10% at the end accounts for trailing silence before the next line. Character-weighting gives longer words proportionally more time (e.g. "beautiful" gets ~1.8× the time of "the").

**Edge cases:**
- Single word: timestamp = `line.timestamp + start_offset` (0.1 × duration offset applied)
- Empty text: returns `[]` (unchanged)
- `total_chars == 0`: guard against division by zero, return `[]`

**Updated tests:** The existing 6 `WordTokenTests` must be updated to match the new formula. New expected values for `test_twoWords_splitsDurationEvenly` (now character-weighted): with "Hello world" (5+5 chars, equal length), both words split evenly within the trimmed window — word[0] at `line.timestamp + 0.1 × duration`, word[1] at `line.timestamp + 0.1 × duration + 0.5 × 0.8 × duration`.

---

## 2. Font Size — Uniform `.title3` Across All Lines

**Changes:** `Hum/Views/KaraokeView.swift`

Inactive lines currently use `.callout` font. Change to `.title3` so all lines (active and inactive) render at the same size. Differentiation between active (lit words at full opacity) and inactive (dim words at 0.3 opacity) is purely through opacity, not size.

In `KaraokeView`, the inactive `else` branch changes from:
```swift
.font(.callout)
```
to:
```swift
.font(.title3)
```

No other font changes needed — `WordFlowView` already uses `.title3.bold()` for active words.

---

## 3. Song Title Header

**Changes:** `Hum/Views/HumWindowView.swift`, `Hum/Window/WindowManager.swift`

A 36px header row is added at the top of the floating window showing the current track title and the hide button.

**Layout (window height: 220 → 260px):**
```
┌────────────────────────────────────────┐
│  Track Title                  [eye✕]  │  ← 36px, padding 12px horizontal
├────────────────────────────────────────┤
│  KaraokeView (lyrics scroll)           │  ← remaining height
└────────────────────────────────────────┘
```

**Title text:**
- Source: `musicObserver.currentTrack?.title ?? ""`
- Style: `.subheadline.bold()`, white, single line, truncated with `lineLimit(1)`
- Alignment: leading

**`HumWindowView` layout:**
```swift
VStack(spacing: 0) {
    HStack {
        Text(musicObserver.currentTrack?.title ?? "")
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .lineLimit(1)
        Spacer()
        HideButton  // see section 4
    }
    .padding(.horizontal, 12)
    .frame(height: 36)

    if !lyricsState.lines.isEmpty {
        KaraokeView(...)
    }
}
.frame(width: 320, height: 260)
.clipShape(RoundedRectangle(cornerRadius: 16))
```

**WindowManager:** update `CGSize` from `(width: 320, height: 220)` to `(width: 320, height: 260)` in `restoreOrSetDefaultPosition()`. When restoring a saved position, only use the saved **origin (X, Y)** — always apply the current hardcoded size `(320, 260)` so old saved frames (220px tall) don't cause a mismatch:
```swift
if let saved = UserDefaults.standard.string(forKey: "windowFrame") {
    let oldFrame = NSRectFromString(saved)
    if oldFrame != .zero {
        panel.setFrame(CGRect(origin: oldFrame.origin, size: CGSize(width: 320, height: 260)), display: false)
        return
    }
}
```

---

## 4. Hide Button + Status Bar Toggle

**Changes:** `Hum/LyricsEngine/LyricsState.swift`, `Hum/Views/HumWindowView.swift`, `Hum/StatusBar/StatusBarController.swift`

### LyricsState

Add `@Published var isManuallyHidden: Bool = false`.

### Hide button in header

SF Symbol `eye.slash` button in the header `HStack`. Tapping sets `lyricsState.isManuallyHidden = true`.

```swift
Button {
    lyricsState.isManuallyHidden = true
} label: {
    Image(systemName: "eye.slash")
        .foregroundColor(.white.opacity(0.6))
        .font(.system(size: 14))
}
.buttonStyle(.plain)
```

### StatusBarController wiring

**Show/Hide menu item:** Replace the current separator-before-Quit with a "Hide Lyrics" / "Show Lyrics" toggle item:

```swift
let hideItem = NSMenuItem(
    title: lyricsState.isManuallyHidden ? "Show Lyrics" : "Hide Lyrics",
    action: #selector(toggleLyricsVisibility),
    keyEquivalent: ""
)
hideItem.tag = 2
```

`@objc func toggleLyricsVisibility()`: flips `lyricsState.isManuallyHidden`.

**Window show/hide logic:** The `CombineLatest` publisher in `observe()` gains `lyricsState.$isManuallyHidden` as a third source:

```swift
Publishers.CombineLatest3(musicObserver.$isPlaying, lyricsState.$lines, lyricsState.$isManuallyHidden)
    .sink { isPlaying, lines, isHidden in
        if isPlaying && !lines.isEmpty && !isHidden {
            windowManager.show()
        } else {
            windowManager.hide()
        }
    }
```

**Auto-reset on track change:** In `handleTrackChange(_:)`, reset `lyricsState.isManuallyHidden = false` when a new track begins (so lyrics reappear for the next song).

**Menu label update:** Subscribe to `lyricsState.$isManuallyHidden` to keep the menu item title ("Show Lyrics" / "Hide Lyrics") in sync.

---

## Testing

No new unit tests for items 2–4 (pure UI/wiring). WordTokenTests must be updated:
- `test_twoWords_splitsDurationEvenly` — new expected values with 10% buffer
- `test_noNextTimestamp_uses5sFallback` — new expected values
- `test_singleWord_usesLineTimestamp` — new expected value (adds start_offset)
- `test_timestampsAreMonotonicallyIncreasing` — still monotonic ✓
- `test_emptyText_returnsEmpty` — unchanged ✓
- `test_extraSpaces_filtered` — unchanged ✓

Manual smoke tests:
- Words appear closer to actual sung timing
- All lyric lines same font size, only opacity differs
- Track title shows at top of window
- Eye.slash button hides window; music continues
- Status bar menu shows "Show Lyrics" after hiding; clicking restores window
- New track auto-shows lyrics even if previous was manually hidden
