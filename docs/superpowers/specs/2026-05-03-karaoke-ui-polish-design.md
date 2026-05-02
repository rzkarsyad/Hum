# Hum — Karaoke UI Polish: Design Spec

**Date:** 2026-05-03
**Platform:** macOS 15+ (Sequoia)

---

## Overview

Two visual improvements to `KaraokeView`:
1. Left-align lyric text (instead of centered)
2. Active lyric line animates in per-glyph using Apple's WWDC 2024 `TextRenderer` API — blur + spring + opacity stagger per character

---

## Deployment Target Change

Current: macOS 13.0. New: **macOS 15.0**.

Reason: `TextRenderer`, `TextAttribute`, `Text.Layout`, and `.textRenderer()` are macOS 15+ only (WWDC 2024). The author is on macOS 15.4; this is a personal app.

Files to update:
- `project.yml` — `deploymentTarget.macOS: "15.0"` (for both Hum and HumTests targets)
- `Hum/Info.plist` — add `LSMinimumSystemVersion: 15.0`

---

## Architecture

### New file: `Hum/Views/TextEffects.swift`

Contains the three types adapted from Apple's WWDC 2024 sample:

**`EmphasisAttribute`** — a `TextAttribute` marker. Applied to the entire text of the active lyric line so every glyph animates individually.

**`AppearanceEffectRenderer: TextRenderer, Animatable`** — drives the per-glyph animation:
- `elapsedTime: TimeInterval` — animatable property, driven from 0 → `totalDuration`
- For runs tagged with `EmphasisAttribute`: each glyph animates with staggered delay — blur fades out, opacity fades in, Y-translation springs from below to 0
- For untagged runs: simple fast easeIn opacity fade
- Spring: `.snappy(duration: elementDuration - 0.05, extraBounce: 0.4)`

**`TextTransition: Transition`** — wraps `AppearanceEffectRenderer` as a SwiftUI `Transition`:
- `totalDuration = 0.9`
- On insert (`phase.isIdentity == true`): `elapsedTime` animates linearly from 0 → 0.9, triggering per-glyph entrance
- On removal: view is simply removed (no exit animation needed — the base layer is always present)

### Modified file: `Hum/Views/KaraokeView.swift`

**Left alignment:**
- `VStack(alignment: .center, spacing: 10)` → `VStack(alignment: .leading, spacing: 10)`
- `.multilineTextAlignment(.center)` → `.multilineTextAlignment(.leading)`

**ZStack per line (two-layer rendering):**

Each lyric line uses a `ZStack(alignment: .leading)` with two layers:

```
Layer 1 — Base (always visible):
  Text(line.text)
  .font(index == active ? .title3.bold() : .callout)
  .foregroundColor(.white)
  .opacity(index == active ? 0.0 : 0.3)
  .animation(.easeOut(duration: 0.2), value: index == active)
  // Fades out when line becomes active, fades in when line becomes inactive
  // Prevents visual pop when the active layer is removed

Layer 2 — Active (conditional, macOS 15+):
  if index == active {
      Text(attributed)          // line.text with EmphasisAttribute on full range
          .font(.title3.bold())
          .foregroundColor(.white)
          .transition(TextTransition())
  }
```

The base layer is hidden (`opacity 0`) when the line is active so the active layer is the sole visible text. When the line becomes inactive, the base layer reappears at 0.3 opacity and the active layer is removed from the hierarchy.

**`AttributedString` helper** — a private helper builds an `AttributedString` from a plain `String` with `EmphasisAttribute` applied to the entire range, so every character participates in the per-glyph animation.

**`id` for transitions** — the active layer uses `.id(index)` so SwiftUI tracks it as a stable identity and fires the transition correctly when `active` changes.

**Scroll behavior** — unchanged: `ScrollViewReader` + `onChange(of: active)` with `easeInOut(duration: 0.35)` scroll to center.

---

## Error Handling

None needed — `TextTransition` is only instantiated when the view is inserted into the hierarchy. If `AttributedString` construction fails (impossible for plain strings), fallback to `Text(line.text)` without attributes.

---

## Testing

No new unit tests — this is pure rendering logic. Verify manually:
- Left-aligned text in floating window
- When track plays, active line animates in with per-glyph blur + spring
- Inactive lines are dimmed at 0.3 opacity
- Scroll follows active line
- No visual glitches when switching tracks rapidly
