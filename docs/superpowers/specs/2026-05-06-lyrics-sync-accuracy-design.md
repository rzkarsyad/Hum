# Lyrics Sync Accuracy — Design Spec

**Date:** 2026-05-06  
**Status:** Approved

---

## Problem

Lyrics drift out of sync during playback for all songs. The drift originates in `MusicObserver`: the interpolation anchor (`baseDate`) is set **after** the AppleScript call completes (~100ms execution time), not before. This means every poll cycle introduces a ~50–100ms lag that accumulates as drift over the course of a song.

Additionally, the manual sync offset stepper in the menu bar is an ergonomic workaround for a problem that should not require manual intervention. It is to be removed entirely.

---

## Root Cause

In `MusicObserver.poll()`:

```swift
basePosition = position
baseDate = Date()   // ← set AFTER AppleScript returns, not before
```

Apple Music samples `player position` at the start of AppleScript execution. By the time we receive the result and set `baseDate`, ~100ms has already passed. The interpolation therefore runs ~100ms slow per poll cycle. At a 500ms poll rate, this is a persistent ~100ms lag. Over time, micro-variations in AppleScript execution time cause the lag to fluctuate, creating audible drift.

---

## Solution

Three targeted changes:

### 1. Fix `baseDate` Timing in `MusicObserver`

Record `baseDate` **before** the AppleScript call, not after:

```swift
private func poll() {
    let prePollDate = Date()
    guard let result = runAppleScript(pollScript) else { return }
    // ... parse result ...
    basePosition = position
    baseDate = prePollDate   // anchor to before execution, not after
}
```

This eliminates the systematic lag. Apple Music's position is approximately what it was at `prePollDate`, so interpolating from there is accurate.

### 2. Reduce Poll Interval: 500ms → 2000ms

The 60fps display timer already handles smooth interpolation. AppleScript polling only needs to provide periodic ground-truth corrections. Reducing from 500ms to 2000ms:
- Lowers CPU and AppleScript overhead by 4×
- Reduces the frequency of potential correction jitter
- Ground-truth accuracy is maintained via interpolation between polls

Add seek detection: if `|reported position − interpolated position| > 1.5s`, treat it as a user seek and update `basePosition`/`baseDate` immediately (hard correction).

### 3. Remove `syncOffset`

`syncOffset` was a workaround for the timing inaccuracy fixed above. Remove it from all layers:

- `LyricsState`: remove `@Published var syncOffset: TimeInterval`
- `StatusBarController`: remove sync offset label (tag 1), stepper (index 1), `offsetChanged()` method, and all syncOffset references in `handleTrackChange()`
- `HumWindowView`: change `at: musicObserver.playbackPosition + lyricsState.syncOffset` → `at: musicObserver.playbackPosition`

---

## Files Changed

| File | Change |
|------|--------|
| `MusicObserver/MusicObserver.swift` | Fix `baseDate`, reduce poll interval to 2s, add seek detection |
| `LyricsEngine/LyricsState.swift` | Remove `syncOffset` property |
| `StatusBar/StatusBarController.swift` | Remove offset label, stepper, `offsetChanged()`, syncOffset wiring |
| `Views/HumWindowView.swift` | Remove `+ lyricsState.syncOffset` from `activeLineIndex` |

No changes to `LyricsEngine`, `LRCParser`, `KaraokeView`, `WindowManager`, or `AppDelegate`.

---

## Data Flow After Change

```
AppleScript (2s poll, baseDate = prePollDate)
    ↓ lastKnownPosition + baseDate
MusicObserver display timer (60fps interpolation)
    ↓ estimatedPosition (published)
HumWindowView → activeIndex(in:at:)
    ↓ active line index
KaraokeView (Equatable guard, re-renders only on index change)
```

---

## Limitations

This fix eliminates the timing mechanism drift. However, if LRCLIB provides an LRC file whose timestamps were generated from a different edit of the track (e.g., different intro length, live version, remaster), some offset may remain. That is a data quality issue outside the scope of this fix. The solution to that class of problem is a different lyrics source, not a timing adjustment.

---

## Testing

1. Play a song with known lyrics → verify lyrics appear at correct words throughout (not just the start)
2. Seek to middle of song → verify lyrics resync correctly within ≤2s
3. Pause and resume → verify no position jump on resume
4. Verify menu no longer shows Sync Offset label/stepper
5. Run existing 18 unit tests → all must pass
