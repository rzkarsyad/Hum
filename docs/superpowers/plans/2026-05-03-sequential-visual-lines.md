# Hum — Sequential Visual Line Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a lyric line wraps into multiple visual lines, animate each visual line sequentially — visual line 1 completes before visual line 2 starts.

**Architecture:** Single change to `AppearanceEffectRenderer.draw(layout:in:)` in `TextEffects.swift`. Replace the current `flattenedRuns` iteration (which treats all glyphs as one stream) with a per-visual-line loop. `totalDuration` is divided equally across visual lines; within each line, glyphs stagger using the line's own time budget.

**Tech Stack:** SwiftUI TextRenderer (macOS 15+), Text.Layout

---

## File Map

| Path | Change |
|------|--------|
| `Hum/Views/TextEffects.swift` | Replace `draw(layout:in:)` and `elementDelay(count:)` with per-visual-line logic |

---

### Task 1: Sequential visual line animation

**Files:**
- Modify: `Hum/Views/TextEffects.swift`

- [ ] **Step 1: Replace the full `AppearanceEffectRenderer` struct in `TextEffects.swift`**

Keep `EmphasisAttribute`, `Text.Layout` extension, and `TextTransition` UNCHANGED. Replace only the `AppearanceEffectRenderer` struct:

```swift
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
        let layoutLines = Array(layout)

        // Count emphasized chars per visual line
        let charsPerLine: [Int] = layoutLines.map { line in
            line.reduce(0) { $0 + ($1[EmphasisAttribute.self] != nil ? $1.count : 0) }
        }
        let nonEmptyCount = charsPerLine.filter { $0 > 0 }.count
        let perLineDuration = nonEmptyCount > 0
            ? totalDuration / TimeInterval(nonEmptyCount)
            : totalDuration

        var lineStartTime: TimeInterval = 0

        for (i, line) in layoutLines.enumerated() {
            let lineChars = charsPerLine[i]

            if lineChars == 0 {
                for run in line {
                    var copy = context
                    copy.opacity = UnitCurve.easeIn.value(at: elapsedTime / 0.2)
                    copy.draw(run)
                }
                continue
            }

            let lineElapsed = max(0, elapsedTime - lineStartTime)
            let stagger = delay(count: lineChars, duration: perLineDuration)

            var charIdx = 0
            for run in line {
                if run[EmphasisAttribute.self] != nil {
                    for slice in run {
                        let timeOffset = TimeInterval(charIdx) * stagger
                        let elementTime = max(0, min(lineElapsed - timeOffset, elementDuration))
                        var copy = context
                        draw(slice, at: elementTime, in: &copy)
                        charIdx += 1
                    }
                } else {
                    var copy = context
                    copy.opacity = UnitCurve.easeIn.value(at: lineElapsed / 0.2)
                    copy.draw(run)
                }
            }

            lineStartTime += perLineDuration
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

    private func delay(count: Int, duration: TimeInterval) -> TimeInterval {
        let count = TimeInterval(count)
        let remaining = duration - count * elementDuration
        return max(remaining / (count + 1), (duration - elementDuration) / count)
    }
}
```

Key changes from current:
- `draw(layout:in:)` now iterates `Array(layout)` (visual lines) instead of `layout.flattenedRuns`
- `totalDuration` is divided equally by `nonEmptyCount` (number of visual lines with emphasized content)
- Each visual line starts at `lineStartTime` which advances by `perLineDuration` after each line
- Within a visual line, glyphs stagger using `delay(count:duration:)` relative to the line's own time budget
- `elementDelay(count:)` is replaced by the private `delay(count:duration:)` helper that takes an explicit duration

For single-line lyrics (most common case), `nonEmptyCount = 1`, `perLineDuration = totalDuration`, and behavior is identical to before.

- [ ] **Step 2: Build + run all tests**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(Test Suite.*passed|FAIL|error:|BUILD)"
```

Expected: `** BUILD SUCCEEDED **`, all 18 tests PASS.

- [ ] **Step 3: Commit**

```bash
git add Hum/Views/TextEffects.swift
git commit -m "feat: sequential visual line animation — line 2 waits for line 1 to finish"
```
