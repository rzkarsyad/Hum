# Hum — Per-Line TextEffects + Resizable Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Revert lyric animation to per-line TextTransition (remove all per-word complexity) and make the floating window user-resizable.

**Architecture:** Two tasks — (1) delete per-word files, restore TextEffects.swift, rewrite KaraokeView with ZStack per-line TextTransition; (2) add `.resizable` to FloatingPanel, save/restore full frame on both move and resize, remove fixed frame from HumWindowView.

**Tech Stack:** SwiftUI TextRenderer (macOS 15+), AppKit NSPanel `.resizable` style mask

---

## File Map

| Path | Change |
|------|--------|
| `Hum/Models/WordToken.swift` | **Delete** |
| `Hum/Views/WordFlowView.swift` | **Delete** |
| `HumTests/WordTokenTests.swift` | **Delete** |
| `Hum/Views/TextEffects.swift` | **Restore** (EmphasisAttribute, AppearanceEffectRenderer, TextTransition) |
| `Hum/Views/KaraokeView.swift` | Rewrite — ZStack per-line with TextTransition, remove WordFlowView/WordToken refs |
| `Hum/Views/HumWindowView.swift` | Remove fixed `.frame(width:height:)`, use flexible sizing |
| `Hum/Window/WindowManager.swift` | Add `.resizable` to FloatingPanel, add `windowDidResize`, restore full saved frame |

---

### Task 1: Per-line TextEffects animation

**Files:**
- Delete: `Hum/Models/WordToken.swift`
- Delete: `Hum/Views/WordFlowView.swift`
- Delete: `HumTests/WordTokenTests.swift`
- Create: `Hum/Views/TextEffects.swift`
- Modify: `Hum/Views/KaraokeView.swift`

- [ ] **Step 1: Delete per-word files**

```bash
rm Hum/Models/WordToken.swift
rm Hum/Views/WordFlowView.swift
rm HumTests/WordTokenTests.swift
```

- [ ] **Step 2: Create `Hum/Views/TextEffects.swift`**

```swift
import SwiftUI

struct EmphasisAttribute: TextAttribute {}

struct AppearanceEffectRenderer: TextRenderer, Animatable {
    var elapsedTime: TimeInterval
    var elementDuration: TimeInterval
    var totalDuration: TimeInterval

    var spring: Spring {
        .snappy(duration: elementDuration - 0.05, extraBounce: 0.4)
    }

    var animatableData: Double {
        get { elapsedTime }
        set { elapsedTime = newValue }
    }

    init(elapsedTime: TimeInterval, elementDuration: Double = 0.4, totalDuration: TimeInterval) {
        self.elapsedTime = min(elapsedTime, totalDuration)
        self.elementDuration = min(elementDuration, totalDuration)
        self.totalDuration = totalDuration
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for run in layout.flattenedRuns {
            if run[EmphasisAttribute.self] != nil {
                let delay = elementDelay(count: run.count)
                for (index, slice) in run.enumerated() {
                    let timeOffset = TimeInterval(index) * delay
                    let elementTime = max(0, min(elapsedTime - timeOffset, elementDuration))
                    var copy = context
                    draw(slice, at: elementTime, in: &copy)
                }
            } else {
                var copy = context
                copy.opacity = UnitCurve.easeIn.value(at: elapsedTime / 0.2)
                copy.draw(run)
            }
        }
    }

    func draw(_ slice: Text.Layout.RunSlice, at time: TimeInterval, in context: inout GraphicsContext) {
        let progress = time / elementDuration
        let opacity = UnitCurve.easeIn.value(at: 1.4 * progress)
        let blurRadius =
            slice.typographicBounds.rect.height / 16 *
            UnitCurve.easeIn.value(at: 1 - progress)
        let translationY = spring.value(
            fromValue: -slice.typographicBounds.descent,
            toValue: 0,
            initialVelocity: 0,
            time: time)
        context.translateBy(x: 0, y: translationY)
        context.addFilter(.blur(radius: blurRadius))
        context.opacity = opacity
        context.draw(slice, options: .disablesSubpixelQuantization)
    }

    func elementDelay(count: Int) -> TimeInterval {
        let count = TimeInterval(count)
        let remainingTime = totalDuration - count * elementDuration
        return max(remainingTime / (count + 1), (totalDuration - elementDuration) / count)
    }
}

extension Text.Layout {
    var flattenedRuns: some RandomAccessCollection<Text.Layout.Run> {
        self.flatMap { line in line }
    }
}

struct TextTransition: Transition {
    static var properties: TransitionProperties {
        TransitionProperties(hasMotion: true)
    }

    func body(content: Content, phase: TransitionPhase) -> some View {
        let duration = 0.9
        let elapsedTime = phase.isIdentity ? duration : 0
        let renderer = AppearanceEffectRenderer(
            elapsedTime: elapsedTime,
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

- [ ] **Step 3: Rewrite `Hum/Views/KaraokeView.swift`**

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

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        ZStack(alignment: .leading) {
                            // Base — always present; hidden when active, dim when inactive
                            Text(line.text)
                                .font(.title3.bold())
                                .foregroundColor(.white)
                                .opacity(index == active ? 0.0 : 0.3)
                                .animation(.easeOut(duration: 0.2), value: index == active)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Active — per-glyph TextTransition on insertion
                            if index == active {
                                Text(line.text)
                                    .customAttribute(EmphasisAttribute())
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .transition(.asymmetric(
                                        insertion: AnyTransition(TextTransition()),
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

- [ ] **Step 4: Regenerate project and build**

```bash
xcodegen generate
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Run remaining tests (18 total — WordTokenTests deleted)**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(Test Suite.*passed|FAIL|error:|BUILD)"
```

Expected: All 18 tests PASS (LRCParser×8 + LyricsEngine×5 + KaraokeActiveLine×5).

- [ ] **Step 6: Commit**

```bash
git add Hum/Views/TextEffects.swift Hum/Views/KaraokeView.swift Hum.xcodeproj/
git rm Hum/Models/WordToken.swift Hum/Views/WordFlowView.swift HumTests/WordTokenTests.swift
git commit -m "feat: per-line TextTransition animation, remove per-word complexity"
```

---

### Task 2: Resizable window

**Files:**
- Modify: `Hum/Window/WindowManager.swift`
- Modify: `Hum/Views/HumWindowView.swift`

- [ ] **Step 1: Replace `Hum/Window/WindowManager.swift`**

```swift
import AppKit
import SwiftUI

final class WindowManager: NSObject, NSWindowDelegate {
    private let panel: FloatingPanel

    init(lyricsState: LyricsState, musicObserver: MusicObserver) {
        panel = FloatingPanel()
        super.init()
        panel.delegate = self
        let rootView = HumWindowView(lyricsState: lyricsState, musicObserver: musicObserver)
        panel.contentView = NSHostingView(rootView: rootView)
        restoreOrSetDefaultPosition()
    }

    func show() { panel.orderFront(nil) }
    func hide() { panel.orderOut(nil) }

    func windowDidMove(_ notification: Notification) {
        saveFrame()
    }

    func windowDidResize(_ notification: Notification) {
        saveFrame()
    }

    private func saveFrame() {
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "windowFrame")
    }

    private func restoreOrSetDefaultPosition() {
        if let saved = UserDefaults.standard.string(forKey: "windowFrame") {
            let savedFrame = NSRectFromString(saved)
            if savedFrame != .zero {
                panel.setFrame(savedFrame, display: false)
                return
            }
        }
        let size = CGSize(width: 320, height: 276)
        guard let screen = NSScreen.main else { return }
        let origin = CGPoint(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.minY + 60
        )
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
    }
}

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
}
```

Key changes:
- `FloatingPanel` style mask: added `.resizable` — enables dragging window edges to resize
- `minSize = CGSize(width: 200, height: 150)` — prevents window from becoming too small
- `windowDidResize` delegate method added — saves frame on resize
- `saveFrame()` helper extracted — shared by move and resize
- `restoreOrSetDefaultPosition()` now restores the FULL saved frame (position + size), not just origin

- [ ] **Step 2: Replace `Hum/Views/HumWindowView.swift`**

```swift
import SwiftUI

struct HumWindowView: View {
    @ObservedObject var lyricsState: LyricsState
    @ObservedObject var musicObserver: MusicObserver

    var body: some View {
        ZStack {
            VibrancyView()
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(musicObserver.currentTrack?.title ?? "")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(musicObserver.currentTrack?.artist ?? "")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer()
                    Button {
                        lyricsState.isManuallyHidden = true
                    } label: {
                        Image(systemName: "eye.slash")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(height: 52)

                if !lyricsState.lines.isEmpty {
                    KaraokeView(
                        lines: lyricsState.lines,
                        musicObserver: musicObserver,
                        syncOffset: lyricsState.syncOffset
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

Key change: `.frame(width: 320, height: 276)` → `.frame(maxWidth: .infinity, maxHeight: .infinity)` — the view now fills whatever size the panel is, enabling free resize.

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Run all tests**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(Test Suite.*passed|FAIL|error:|BUILD)"
```

Expected: All 18 tests PASS, `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add Hum/Window/WindowManager.swift Hum/Views/HumWindowView.swift
git commit -m "feat: resizable floating window with full frame persistence"
```
