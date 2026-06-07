# Hum — Karaoke UI Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Left-align lyric text and add Apple-style per-glyph entrance animation (blur + spring + staggered opacity) when the active lyric line changes.

**Architecture:** Three sequential tasks — (1) raise deployment target to macOS 15 to unlock TextRenderer APIs; (2) create `TextEffects.swift` with `EmphasisAttribute`, `AppearanceEffectRenderer`, and `TextTransition` (adapted from Apple WWDC 2024); (3) redesign `KaraokeView` with left alignment, a ZStack two-layer pattern (base layer always present + active layer with TextTransition), and the modern two-param `onChange` API.

**Tech Stack:** SwiftUI `TextRenderer` (macOS 15+), `TextAttribute`, `Text.Layout`, `Spring`, `UnitCurve`, xcodegen

---

## File Map

| Path | Change |
|------|--------|
| `project.yml` | `deploymentTarget.macOS` + `MACOSX_DEPLOYMENT_TARGET`: `"13.0"` → `"15.0"` |
| `Hum/Info.plist` | Add `LSMinimumSystemVersion: 15.0` |
| `Hum/Views/TextEffects.swift` | New: `EmphasisAttribute`, `AppearanceEffectRenderer`, `TextTransition`, `Text.Layout` extension |
| `Hum/Views/KaraokeView.swift` | Left align + ZStack two-layer + TextTransition + two-param `onChange` |

---

### Task 1: Raise deployment target to macOS 15

**Files:**
- Modify: `project.yml`
- Modify: `Hum/Info.plist`

- [ ] **Step 1: Replace `project.yml` with updated deployment target**

```yaml
name: Hum
options:
  bundleIdPrefix: com.rzkarsyad
  deploymentTarget:
    macOS: "15.0"
targets:
  Hum:
    type: application
    platform: macOS
    sources:
      - Hum
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.rzkarsyad.Hum
        SWIFT_VERSION: "5.9"
        INFOPLIST_FILE: Hum/Info.plist
        CODE_SIGN_IDENTITY: "-"
        CODE_SIGN_STYLE: Manual
    entitlements:
      path: Hum/Hum.entitlements
      properties:
        com.apple.security.app-sandbox: false
        com.apple.security.automation.apple-events: true
        com.apple.security.network.client: true
    dependencies:
      - sdk: ServiceManagement.framework
  HumTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - HumTests
    dependencies:
      - target: Hum
    settings:
      base:
        MACOSX_DEPLOYMENT_TARGET: "15.0"
        SWIFT_VERSION: "5.9"
        CODE_SIGNING_ALLOWED: "NO"
```

- [ ] **Step 2: Add `LSMinimumSystemVersion` to `Hum/Info.plist`**

Add inside the root `<dict>`, after `CFBundleShortVersionString`:

```xml
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
```

The full `Info.plist` should look like:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Hum reads your currently playing track from Apple Music to display lyrics.</string>
    <key>NSAppleMediaLibraryUsageDescription</key>
    <string>Hum accesses your music library to display synced lyrics.</string>
    <key>CFBundleName</key>
    <string>Hum</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
</dict>
</plist>
```

- [ ] **Step 3: Regenerate project and verify build + all tests pass**

```bash
xcodegen generate
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(PASS|FAIL|error:|BUILD)"
```

Expected: `** BUILD SUCCEEDED **`, all 18 tests PASS.

- [ ] **Step 4: Commit**

```bash
git add project.yml Hum/Info.plist Hum.xcodeproj/
git commit -m "feat: raise deployment target to macOS 15 for TextRenderer API"
```

---

### Task 2: TextEffects.swift

**Files:**
- Create: `Hum/Views/TextEffects.swift`

- [ ] **Step 1: Create `Hum/Views/TextEffects.swift`**

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

- [ ] **Step 2: Regenerate and build**

```bash
xcodegen generate
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Hum/Views/TextEffects.swift Hum.xcodeproj/
git commit -m "feat: add TextEffects with AppearanceEffectRenderer and TextTransition"
```

---

### Task 3: KaraokeView redesign

**Files:**
- Modify: `Hum/Views/KaraokeView.swift`

- [ ] **Step 1: Replace the full contents of `Hum/Views/KaraokeView.swift`**

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
                            // Base layer — always present, fades out when this line is active
                            Text(line.text)
                                .font(index == active ? .title3.bold() : .callout)
                                .foregroundColor(.white)
                                .opacity(index == active ? 0.0 : 0.3)
                                .animation(.easeOut(duration: 0.2), value: index == active)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Active layer — animates in with per-glyph TextTransition
                            if index == active {
                                Text(line.text)
                                    .customAttribute(EmphasisAttribute())
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .transition(.asymmetric(
                                        insertion: TextTransition(),
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

Changes from the previous version:
- `VStack(alignment: .center)` → `.leading`
- Each line is now a `ZStack(alignment: .leading)` with two layers
- Base layer: `opacity 0.0` when active (hidden behind active layer), `0.3` when inactive, animated with `.easeOut(duration: 0.2)` to prevent pop on switch
- Active layer: conditional `if index == active`, uses `.customAttribute(EmphasisAttribute())` so all glyphs animate per-character
- `.transition(.asymmetric(insertion: TextTransition(), removal: .opacity.animation(.easeOut(duration: 0.15))))` — beautiful entrance, quick fade exit
- `.onChange(of: active) { _, idx in }` — two-param form (macOS 15 non-deprecated API)
- `activeIndex` function is unchanged

- [ ] **Step 2: Verify existing tests still pass**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/KaraokeActiveLineTests 2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: All 5 `KaraokeActiveLineTests` PASS — `activeIndex` function is unchanged.

- [ ] **Step 3: Commit**

```bash
git add Hum/Views/KaraokeView.swift
git commit -m "feat: left-align lyrics and add per-glyph TextTransition on active line"
```
