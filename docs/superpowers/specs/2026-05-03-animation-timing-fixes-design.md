# Hum — Animation & Timing Fixes: Design Spec

**Date:** 2026-05-03

---

## Overview

Four targeted fixes based on user feedback:
1. Add artist name below song title in header
2. Uniform bold font weight across all lyric lines
3. Fix "double" animation effect — replace ZStack+TextTransition with single-layer spring
4. Improve word timing — remove start offset, keep 10% end buffer only

---

## 1. Artist Name in Header

**File:** `Hum/Views/HumWindowView.swift`

Replace the single-line title `HStack` with a `VStack` inside the `HStack` to show title + artist:

```
┌─ Header (52px) ──────────────────────────────┐
│  Song Title                         [eye✕]  │
│  Artist Name                                │
└─────────────────────────────────────────────┘
```

- Title: `.subheadline.bold()`, white, truncated
- Artist: `.caption`, white at 0.7 opacity, truncated
- Header height: 36 → 52px
- Window height: 260 → 276px (to accommodate 16px extra header)
- WindowManager: update size to `(320, 276)` — restore only origin

---

## 2. Font Weight Uniformity

**File:** `Hum/Views/KaraokeView.swift`

Inactive lines currently use `.title3` (regular). Change to `.title3.bold()` to match active `WordFlowView` words.

---

## 3. Animation Fix — Single Layer Spring

**Files:** `Hum/Views/WordFlowView.swift`, `Hum/Views/TextEffects.swift` (delete)

**Root cause of "double" effect:** The ZStack has a permanent dim base layer (opacity 0.3, at normal position) plus a conditionally-inserted lit layer that animates in from slightly below with blur (TextTransition, 0.9s). During animation, both layers are simultaneously visible at different positions and opacities, creating a double-text visual glitch.

**Root cause of no-sequential:** TextTransition takes 0.9s per word. Words appear every ~0.3–0.5s, causing heavy animation overlap.

**Fix:** Remove ZStack entirely. One `Text` view per word with:
- `opacity`: `isLit ? 1.0 : 0.3` — animated with `.spring(duration: 0.2, bounce: 0.3)`
- `offset(y:)`: `isLit ? 0 : 3` — subtle 3pt lift on appearance, same spring
- No base/lit split → no double
- 0.2s spring → completes well before next word (~0.3–0.5s later) → appears sequential

`TextEffects.swift` (EmphasisAttribute, AppearanceEffectRenderer, TextTransition) is deleted since it's no longer referenced.

---

## 4. Timing Improvement

**Files:** `Hum/Models/WordToken.swift`, `HumTests/WordTokenTests.swift`

**Current:** `startOffset = duration * 0.1`, `effectiveDuration = duration * 0.8`

LRC line timestamps mark the moment the line starts being sung. Adding a 10% start offset causes the first word to appear late. Remove the start offset entirely:

**New formula:**
```
startOffset       = 0
effectiveDuration = duration × 0.9   (keep 10% trailing buffer only)

word[i].timestamp = line.timestamp + (cumulative[i] / totalChars) × effectiveDuration
```

Updated test expectations for affected cases:
- `test_singleWord`: `10.0 + 0 = 10.0`
- `test_twoEqualWords`: word[0]=`10.0`, word[1]=`10.0 + 0.5×1.8 = 10.9`
- `test_noNextTimestamp`: word[0]=`10.0`, word[1]=`10.0 + 0.5×4.5 = 12.25`
- `test_longerWordGetsMoreTime`: `hi`(2)+`world`(5)=7, duration=7.0, effective=6.3. word[0]=`0.0`, word[1]=`0.0 + (2/7)*6.3 = 1.8`

---

## Testing

- `WordTokenTests`: update 4 expected values, all 7 tests must pass
- Manual: first word of each line appears at line timestamp (no delay), words light up sequentially with visible gap, no double animation
