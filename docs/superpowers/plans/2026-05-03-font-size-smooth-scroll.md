# Hum — Text Size Control + Smooth Scroll Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a font size stepper in the status bar menu (12–36pt, default 20pt, persisted) and replace the scroll animation with a smooth spring that mimics Apple Music's lyrics view.

**Architecture:** Two tasks — (1) add `fontSize` to `LyricsState`, update `KaraokeView` with dynamic font + spring scroll; (2) update `HumWindowView` to pass `fontSize` and `StatusBarController` to add the font size stepper menu item with `UserDefaults` persistence.

**Tech Stack:** SwiftUI, Combine, AppKit NSStepper, UserDefaults

---

## File Map

| Path | Change |
|------|--------|
| `Hum/LyricsEngine/LyricsState.swift` | Add `@Published var fontSize: CGFloat` (default 20, restored from UserDefaults) |
| `Hum/Views/KaraokeView.swift` | Add `fontSize: CGFloat` param; use `.system(size:weight:)`; scroll → `.spring(duration: 0.5, bounce: 0.15)` |
| `Hum/Views/HumWindowView.swift` | Pass `lyricsState.fontSize` to `KaraokeView` |
| `Hum/StatusBar/StatusBarController.swift` | Add font size label (tag 4) + NSStepper after sync offset section |

---

### Task 1: LyricsState + KaraokeView

**Files:**
- Modify: `Hum/LyricsEngine/LyricsState.swift`
- Modify: `Hum/Views/KaraokeView.swift`

- [ ] **Step 1: Update `Hum/LyricsEngine/LyricsState.swift`**

```swift
import Foundation

@MainActor
final class LyricsState: ObservableObject {
    @Published var lines: [LyricLine] = []
    @Published var syncOffset: TimeInterval = 0
    @Published var isManuallyHidden: Bool = false
    @Published var noLyricsFound: Bool = false
    @Published var fontSize: CGFloat = {
        let stored = UserDefaults.standard.double(forKey: "humFontSize")
        return stored >= 12 ? CGFloat(stored) : 20
    }()
}
```

- [ ] **Step 2: Replace `Hum/Views/KaraokeView.swift`**

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
    let fontSize: CGFloat

    private var active: Int? {
        activeIndex(in: lines, at: musicObserver.playbackPosition + syncOffset)
    }

    private func lineDuration(for index: Int) -> TimeInterval {
        guard index + 1 < lines.count else { return 0.9 }
        let available = lines[index + 1].timestamp - lines[index].timestamp
        return max(available, 0.3)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        ZStack(alignment: .leading) {
                            Text(line.text)
                                .font(.system(size: fontSize, weight: .bold))
                                .foregroundColor(.white)
                                .opacity(0.3)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if index == active {
                                Text(line.text)
                                    .customAttribute(EmphasisAttribute())
                                    .font(.system(size: fontSize, weight: .bold))
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
                    withAnimation(.spring(duration: 0.5, bounce: 0.15)) {
                        proxy.scrollTo(idx, anchor: .center)
                    }
                }
            }
        }
    }
}
```

Changes from current:
- Added `let fontSize: CGFloat` parameter
- `.title2.bold()` → `.system(size: fontSize, weight: .bold)` on both Text views
- Scroll animation: `.easeInOut(duration: 0.35)` → `.spring(duration: 0.5, bounce: 0.15)`

- [ ] **Step 3: Do NOT build or commit yet**

`HumWindowView` still calls `KaraokeView` without `fontSize` — it will fail to compile until Task 2 adds the argument. Proceed directly to Task 2.

---

### Task 2: HumWindowView + StatusBarController

**Files:**
- Modify: `Hum/Views/HumWindowView.swift`
- Modify: `Hum/StatusBar/StatusBarController.swift`

- [ ] **Step 1: Update `KaraokeView` call in `Hum/Views/HumWindowView.swift`**

Find the `KaraokeView(...)` call. Add `fontSize: lyricsState.fontSize`:

```swift
                if !lyricsState.lines.isEmpty {
                    KaraokeView(
                        lines: lyricsState.lines,
                        musicObserver: musicObserver,
                        syncOffset: lyricsState.syncOffset,
                        fontSize: lyricsState.fontSize
                    )
                } else if lyricsState.noLyricsFound {
                    VStack {
                        Spacer()
                        Text("Oops, we don't have lyrics for this one")
                            .font(.callout)
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        Spacer()
                    }
                }
```

- [ ] **Step 2: Add font size section to `buildMenu()` in `StatusBarController.swift`**

Find the first `menu.addItem(.separator())` in `buildMenu()` (the one after the sync offset stepper). Insert BEFORE that separator:

```swift
        let fontSizeLabel = NSMenuItem(title: "Text Size: \(Int(lyricsState.fontSize))pt", action: nil, keyEquivalent: "")
        fontSizeLabel.tag = 4
        menu.addItem(fontSizeLabel)

        let fontStepperItem = NSMenuItem()
        let fontStepper = NSStepper()
        fontStepper.minValue = 12
        fontStepper.maxValue = 36
        fontStepper.increment = 2
        fontStepper.doubleValue = Double(lyricsState.fontSize)
        fontStepper.target = self
        fontStepper.action = #selector(fontSizeChanged(_:))
        fontStepper.frame = CGRect(x: 8, y: 0, width: 100, height: 22)
        fontStepperItem.view = fontStepper
        menu.addItem(fontStepperItem)
```

- [ ] **Step 3: Add `fontSizeChanged` action to `StatusBarController`**

Add after `offsetChanged`:

```swift
    @objc private func fontSizeChanged(_ stepper: NSStepper) {
        let size = CGFloat(stepper.doubleValue)
        lyricsState.fontSize = size
        UserDefaults.standard.set(Double(size), forKey: "humFontSize")
        statusItem.menu?.item(withTag: 4)?.title = "Text Size: \(Int(size))pt"
    }
```

- [ ] **Step 4: Build + run all tests**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(Test Suite.*passed|FAIL|error:|BUILD)"
```

Expected: `** BUILD SUCCEEDED **`, all 18 tests PASS.

- [ ] **Step 5: Commit everything**

```bash
git add Hum/LyricsEngine/LyricsState.swift Hum/Views/KaraokeView.swift Hum/Views/HumWindowView.swift Hum/StatusBar/StatusBarController.swift
git commit -m "feat: text size stepper in menu (12-36pt) and smooth spring scroll animation"
```
