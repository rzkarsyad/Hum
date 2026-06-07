# Hum — Resize Cursor + Dynamic TextTransition Duration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show resize cursors at window edges, and sync TextTransition animation duration to the time available before the next lyric line.

**Architecture:** Two independent tasks — (1) override `resetCursorRects()` in `FloatingPanel` to add per-edge cursor rects on the content view; (2) add a `duration` parameter to `TextTransition` (scaled `elementDuration`) and compute it from line timestamps in `KaraokeView`.

**Tech Stack:** AppKit NSCursor, SwiftUI TextRenderer (macOS 15+)

---

## File Map

| Path | Change |
|------|--------|
| `Hum/Window/WindowManager.swift` | Override `resetCursorRects()` in `FloatingPanel` |
| `Hum/Views/TextEffects.swift` | Add `duration` param to `TextTransition`, scale `elementDuration` |
| `Hum/Views/KaraokeView.swift` | Add `lineDuration(for:)`, pass to `TextTransition` |

---

### Task 1: Resize cursors at window edges

**Files:**
- Modify: `Hum/Window/WindowManager.swift`

- [ ] **Step 1: Add `resetCursorRects()` to `FloatingPanel` in `WindowManager.swift`**

The `FloatingPanel` class currently has two overrides (`canBecomeKey`, `canBecomeMain`). Add a third — `resetCursorRects()` — which adds edge cursor rects to the content view. The full `FloatingPanel` class becomes:

```swift
private final class FloatingPanel: NSPanel {
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        minSize = CGSize(width: 200, height: 150)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard let cv = contentView else { return }
        let b = cv.bounds
        let e: CGFloat = 8

        // Left and right edges → horizontal resize cursor
        cv.addCursorRect(CGRect(x: 0,            y: e,            width: e, height: b.height - 2 * e), cursor: .resizeLeftRight)
        cv.addCursorRect(CGRect(x: b.width - e,  y: e,            width: e, height: b.height - 2 * e), cursor: .resizeLeftRight)

        // Top and bottom edges → vertical resize cursor
        cv.addCursorRect(CGRect(x: e,            y: 0,            width: b.width - 2 * e, height: e), cursor: .resizeUpDown)
        cv.addCursorRect(CGRect(x: e,            y: b.height - e, width: b.width - 2 * e, height: e), cursor: .resizeUpDown)

        // Corners → horizontal resize cursor (no diagonal cursor in NSCursor)
        cv.addCursorRect(CGRect(x: 0,           y: 0,            width: e, height: e), cursor: .resizeLeftRight)
        cv.addCursorRect(CGRect(x: b.width - e, y: 0,            width: e, height: e), cursor: .resizeLeftRight)
        cv.addCursorRect(CGRect(x: 0,           y: b.height - e, width: e, height: e), cursor: .resizeLeftRight)
        cv.addCursorRect(CGRect(x: b.width - e, y: b.height - e, width: e, height: e), cursor: .resizeLeftRight)
    }
}
```

How it works: macOS calls `resetCursorRects()` whenever the window needs to re-establish cursor tracking (on resize, expose, etc.). We call `super.resetCursorRects()` first (clears old rects), then add edge rects to `contentView`. When the mouse enters an edge zone, macOS automatically sets that cursor.

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Hum/Window/WindowManager.swift
git commit -m "feat: resize cursors at window edges via resetCursorRects"
```

---

### Task 2: Dynamic TextTransition duration synced to line timing

**Files:**
- Modify: `Hum/Views/TextEffects.swift`
- Modify: `Hum/Views/KaraokeView.swift`

**Design:**
- `TextTransition` accepts a `duration: TimeInterval` parameter (default 0.9 for backward compatibility)
- `elementDuration` scales proportionally: `min(duration × 0.44, 0.4)` — so at duration=0.9 it's ~0.4 (unchanged), at duration=0.3 it's 0.13 (fast)
- `KaraokeView.lineDuration(for:)` computes: `min(max(nextLine.timestamp - thisLine.timestamp) × 0.85, 0.3), 1.5)` — 85% of available time, clamped between 0.3s and 1.5s

Duration examples:
- 0.5s line → animation takes 0.43s (fast, matches quick rhythm)
- 1.5s line → animation takes 1.28s (dramatic)
- 3s+ line → animation takes 1.5s (max, very dramatic)
- Last line or very short → 0.3s minimum (never janky)

- [ ] **Step 1: Update `Hum/Views/TextEffects.swift` — add `duration` to `TextTransition`**

Only `TextTransition` changes. Keep `EmphasisAttribute`, `AppearanceEffectRenderer`, and `Text.Layout` extension exactly as-is. Replace only the `TextTransition` struct:

```swift
struct TextTransition: Transition {
    var duration: TimeInterval

    init(duration: TimeInterval = 0.9) {
        self.duration = duration
    }

    static var properties: TransitionProperties {
        TransitionProperties(hasMotion: true)
    }

    func body(content: Content, phase: TransitionPhase) -> some View {
        let elapsedTime = phase.isIdentity ? duration : 0
        let scaledElementDuration = min(duration * 0.44, 0.4)
        let renderer = AppearanceEffectRenderer(
            elapsedTime: elapsedTime,
            elementDuration: scaledElementDuration,
            totalDuration: duration
        )
        content.transaction { transaction in
            if !transaction.disablesAnimations {
                transaction.animation = .linear(duration: duration)
            }
        } body: { view in
            view.textRenderer(renderer)
        }
    }
}
```

`scaledElementDuration = min(duration * 0.44, 0.4)`:
- duration=0.9 → 0.396 ≈ 0.4 (same as before)
- duration=0.3 → 0.132 (fast glyphs)
- duration=1.5 → min(0.66, 0.4) = 0.4 (capped — longer stagger delay instead)

- [ ] **Step 2: Update `Hum/Views/KaraokeView.swift` — add `lineDuration` and pass to transition**

Add `lineDuration(for:)` method and update the `TextTransition` call. The full `KaraokeView` becomes:

```swift
import SwiftUI

func activeIndex(in lines: [LyricLine], at position: TimeInterval) -> Int? {
    guard !lines.isEmpty else { return nil }
    var result: Int? = nil
    for (i, line) in lines.enumerated() {
        if line.timestamp <= position { result = i } else { break }
    }
    return result
}

struct KaraokeView: View {
    let lines: [LyricLine]
    @ObservedObject var musicObserver: MusicObserver
    let syncOffset: TimeInterval

    private var active: Int? {
        activeIndex(in: lines, at: musicObserver.playbackPosition + syncOffset)
    }

    private func lineDuration(for index: Int) -> TimeInterval {
        guard index + 1 < lines.count else { return 0.9 }
        let available = lines[index + 1].timestamp - lines[index].timestamp
        return min(max(available * 0.85, 0.3), 1.5)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        ZStack(alignment: .leading) {
                            Text(line.text)
                                .font(.title3.bold())
                                .foregroundColor(.white)
                                .opacity(index == active ? 0.0 : 0.3)
                                .animation(.easeOut(duration: 0.2), value: index == active)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if index == active {
                                Text(line.text)
                                    .customAttribute(EmphasisAttribute())
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .transition(.asymmetric(
                                        insertion: AnyTransition(TextTransition(duration: lineDuration(for: index))),
                                        removal: .opacity.animation(.easeOut(duration: 0.15))
                                    ))
                            }
                        }
                        .padding(.horizontal, 16)
                        .id(index)
                    }
                }
                .padding(.vertical, 24)
            }
            .onChange(of: active) { _, idx in
                if let idx {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(idx, anchor: .center)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build + run all tests**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(Test Suite.*passed|FAIL|error:|BUILD)"
```

Expected: `** BUILD SUCCEEDED **`, all 18 tests PASS.

- [ ] **Step 4: Commit**

```bash
git add Hum/Views/TextEffects.swift Hum/Views/KaraokeView.swift
git commit -m "feat: dynamic TextTransition duration synced to lyric line timing"
```
