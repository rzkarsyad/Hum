# Instrumental Dots Indicator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the lyric-pacing bug during instrumental gaps and add a three-dot progress indicator that fills as a long instrumental gap (or intro) plays.

**Architecture:** Replace flat `[LyricLine]` rendering with a merged `[KaraokeItem]` list where long instrumental gaps become first-class `.instrumental` items. A lyric's animation duration is the span to the *next item's start*, so a line before a gap is capped at its natural sung duration (bug fix). The active instrumental item renders an `InstrumentalDotsView` that observes `MusicObserver` directly, updating at 60fps without re-rendering the equatable `KaraokeView`.

**Tech Stack:** Swift 5.9, SwiftUI + AppKit, XCTest, xcodegen, xcodebuild.

---

## File Structure

**New**
- `Hum/Views/KaraokeItem.swift` — `KaraokeItem` enum, tunable constants, `naturalDuration(_:)`, `dotFill(_:progress:)`, `buildItems(from:)`, `activeItemIndex(in:at:)`.
- `Hum/Views/InstrumentalDotsView.swift` — `DotsRow` (presentational) + `InstrumentalDotsView` (observes `MusicObserver`).
- `HumTests/KaraokeItemTests.swift` — unit tests for the pure logic above.

**Modified**
- `Hum/Views/KaraokeView.swift` — render `[KaraokeItem]`; duration from next item start; render dots for instrumental items; forward `musicObserver`.
- `Hum/Views/HumWindowView.swift` — build items, compute active item index, pass items + `musicObserver`.

**Removed**
- The old standalone `activeIndex(in:at:)` in `KaraokeView.swift` is superseded by `activeItemIndex`. Its tests in `HumTests/KaraokeActiveLineTests.swift` will be deleted in Task 6 (the function no longer exists).

---

### Task 1: KaraokeItem model + timing constants + pure helpers

**Files:**
- Create: `Hum/Views/KaraokeItem.swift`
- Test: `HumTests/KaraokeItemTests.swift`

- [ ] **Step 1: Write failing tests for `naturalDuration` and `dotFill`**

Create `HumTests/KaraokeItemTests.swift`:

```swift
import XCTest
@testable import Hum

final class KaraokeItemTests: XCTestCase {

    // MARK: naturalDuration

    func test_naturalDuration_clampsToMin() {
        // 2 chars * 0.13 = 0.26 -> clamps up to MIN_LINE (1.2)
        XCTAssertEqual(naturalDuration(LyricLine(timestamp: 0, text: "hi")), 1.2, accuracy: 0.0001)
    }

    func test_naturalDuration_clampsToMax() {
        let long = String(repeating: "a", count: 100) // 100 * 0.13 = 13 -> clamps to MAX_LINE (5.0)
        XCTAssertEqual(naturalDuration(LyricLine(timestamp: 0, text: long)), 5.0, accuracy: 0.0001)
    }

    func test_naturalDuration_scalesInBetween() {
        let text = String(repeating: "a", count: 20) // 20 * 0.13 = 2.6
        XCTAssertEqual(naturalDuration(LyricLine(timestamp: 0, text: text)), 2.6, accuracy: 0.0001)
    }

    // MARK: dotFill

    func test_dotFill_allEmptyAtZero() {
        XCTAssertEqual(dotFill(0, progress: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(dotFill(1, progress: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(dotFill(2, progress: 0), 0, accuracy: 0.0001)
    }

    func test_dotFill_firstDotMidway() {
        // progress 1/6 -> dot0 = 0.5, others 0
        XCTAssertEqual(dotFill(0, progress: 1.0 / 6.0), 0.5, accuracy: 0.0001)
        XCTAssertEqual(dotFill(1, progress: 1.0 / 6.0), 0, accuracy: 0.0001)
    }

    func test_dotFill_firstDotFullAtThird() {
        XCTAssertEqual(dotFill(0, progress: 1.0 / 3.0), 1, accuracy: 0.0001)
        XCTAssertEqual(dotFill(1, progress: 1.0 / 3.0), 0, accuracy: 0.0001)
    }

    func test_dotFill_allFullAtOne() {
        XCTAssertEqual(dotFill(0, progress: 1), 1, accuracy: 0.0001)
        XCTAssertEqual(dotFill(1, progress: 1), 1, accuracy: 0.0001)
        XCTAssertEqual(dotFill(2, progress: 1), 1, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodegen generate && xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/KaraokeItemTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'naturalDuration' in scope` / `cannot find 'dotFill' in scope`.

- [ ] **Step 3: Create `KaraokeItem.swift` with the model, constants, and pure helpers**

Create `Hum/Views/KaraokeItem.swift`:

```swift
import Foundation

// Tunable timing constants (adjust after manual testing)
let SEC_PER_CHAR: TimeInterval = 0.13
let MIN_LINE: TimeInterval = 1.2
let MAX_LINE: TimeInterval = 5.0
let GAP_THRESHOLD: TimeInterval = 5.0

enum KaraokeItem: Equatable {
    case lyric(LyricLine)
    case instrumental(start: TimeInterval, end: TimeInterval)

    var start: TimeInterval {
        switch self {
        case .lyric(let line): return line.timestamp
        case .instrumental(let start, _): return start
        }
    }
}

/// Estimated natural sung duration of a line, used to cap the appearance
/// animation and to find where an instrumental gap begins.
func naturalDuration(_ line: LyricLine) -> TimeInterval {
    let raw = Double(line.text.count) * SEC_PER_CHAR
    return min(max(raw, MIN_LINE), MAX_LINE)
}

/// Fill amount (0...1) of dot `i` (0..<3) for a gap progress (0...1).
/// dot 0 fills over 0–1/3, dot 1 over 1/3–2/3, dot 2 over 2/3–1.
func dotFill(_ i: Int, progress: Double) -> Double {
    min(max(progress * 3 - Double(i), 0), 1)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodegen generate && xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/KaraokeItemTests 2>&1 | tail -20`
Expected: PASS (all `KaraokeItemTests`).

- [ ] **Step 5: Commit**

```bash
git add Hum/Views/KaraokeItem.swift HumTests/KaraokeItemTests.swift Hum.xcodeproj
git commit -m "feat: KaraokeItem model, timing constants, naturalDuration + dotFill"
```

---

### Task 2: `buildItems(from:)`

**Files:**
- Modify: `Hum/Views/KaraokeItem.swift`
- Test: `HumTests/KaraokeItemTests.swift`

- [ ] **Step 1: Add failing tests for `buildItems`**

Append to `HumTests/KaraokeItemTests.swift` (inside the class):

```swift
    // MARK: buildItems

    private func line(_ t: Double, _ text: String = "x") -> LyricLine {
        LyricLine(timestamp: t, text: text)
    }

    func test_buildItems_empty() {
        XCTAssertTrue(buildItems(from: []).isEmpty)
    }

    func test_buildItems_singleLine_noTrailingItem() {
        let items = buildItems(from: [line(10)])
        XCTAssertEqual(items, [.lyric(line(10))])
    }

    func test_buildItems_insertsIntroWhenFirstLineAfterThreshold() {
        // first line at 6s (>= 5) -> intro instrumental 0..6
        let items = buildItems(from: [line(6), line(8)])
        XCTAssertEqual(items.first, .instrumental(start: 0, end: 6))
    }

    func test_buildItems_noIntroWhenFirstLineEarly() {
        let items = buildItems(from: [line(2), line(4)])
        XCTAssertEqual(items.first, .lyric(line(2)))
    }

    func test_buildItems_insertsGapWhenLongEnough() {
        // line "x" (1 char) -> naturalDuration clamps to MIN_LINE 1.2
        // lineEnd = 0 + 1.2 = 1.2 ; next at 10 -> gap 8.8 >= 5 -> instrumental 1.2..10
        let items = buildItems(from: [line(0), line(10)])
        XCTAssertEqual(items, [.lyric(line(0)), .instrumental(start: 1.2, end: 10), .lyric(line(10))])
    }

    func test_buildItems_noGapWhenShort() {
        // lineEnd = 1.2 ; next at 4 -> remaining 2.8 < 5 -> no instrumental
        let items = buildItems(from: [line(0), line(4)])
        XCTAssertEqual(items, [.lyric(line(0)), .lyric(line(4))])
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/KaraokeItemTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'buildItems' in scope`.

- [ ] **Step 3: Implement `buildItems` in `KaraokeItem.swift`**

Append to `Hum/Views/KaraokeItem.swift`:

```swift
/// Builds the merged display list, inserting `.instrumental` items for the intro
/// and for any inter-line gap that, after the line's natural duration, still leaves
/// at least `GAP_THRESHOLD` seconds of music.
func buildItems(from lines: [LyricLine]) -> [KaraokeItem] {
    guard let first = lines.first else { return [] }

    var items: [KaraokeItem] = []

    if first.timestamp >= GAP_THRESHOLD {
        items.append(.instrumental(start: 0, end: first.timestamp))
    }

    for index in lines.indices {
        let line = lines[index]
        items.append(.lyric(line))

        guard index + 1 < lines.count else { continue }
        let nextStart = lines[index + 1].timestamp
        let lineEnd = line.timestamp + naturalDuration(line)
        if nextStart - lineEnd >= GAP_THRESHOLD {
            items.append(.instrumental(start: lineEnd, end: nextStart))
        }
    }

    return items
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/KaraokeItemTests 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Hum/Views/KaraokeItem.swift HumTests/KaraokeItemTests.swift
git commit -m "feat: buildItems merges lyrics with instrumental gap items"
```

---

### Task 3: `activeItemIndex(in:at:)`

**Files:**
- Modify: `Hum/Views/KaraokeItem.swift`
- Test: `HumTests/KaraokeItemTests.swift`

- [ ] **Step 1: Add failing tests for `activeItemIndex`**

Append to `HumTests/KaraokeItemTests.swift` (inside the class):

```swift
    // MARK: activeItemIndex

    func test_activeItemIndex_nilBeforeFirst() {
        let items: [KaraokeItem] = [.lyric(line(5)), .lyric(line(10))]
        XCTAssertNil(activeItemIndex(in: items, at: 3))
    }

    func test_activeItemIndex_picksInstrumentalInsideGap() {
        // [lyric@0, instrumental 1.2..10, lyric@10]
        let items = buildItems(from: [line(0), line(10)])
        XCTAssertEqual(activeItemIndex(in: items, at: 5), 1) // inside gap -> instrumental
    }

    func test_activeItemIndex_picksLyricBeforeGap() {
        let items = buildItems(from: [line(0), line(10)])
        XCTAssertEqual(activeItemIndex(in: items, at: 0.5), 0) // still the lyric
    }

    func test_activeItemIndex_picksLastWhenPastAll() {
        let items = buildItems(from: [line(0), line(10)])
        XCTAssertEqual(activeItemIndex(in: items, at: 99), items.count - 1)
    }

    func test_activeItemIndex_emptyIsNil() {
        XCTAssertNil(activeItemIndex(in: [], at: 5))
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/KaraokeItemTests 2>&1 | tail -20`
Expected: FAIL — `cannot find 'activeItemIndex' in scope`.

- [ ] **Step 3: Implement `activeItemIndex` in `KaraokeItem.swift`**

Append to `Hum/Views/KaraokeItem.swift`:

```swift
/// Last item whose start time is <= position; nil if before the first item.
func activeItemIndex(in items: [KaraokeItem], at position: TimeInterval) -> Int? {
    guard !items.isEmpty else { return nil }
    var lo = 0, hi = items.count - 1, result: Int? = nil
    while lo <= hi {
        let mid = (lo + hi) / 2
        if items[mid].start <= position {
            result = mid
            lo = mid + 1
        } else {
            hi = mid - 1
        }
    }
    return result
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/KaraokeItemTests 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Hum/Views/KaraokeItem.swift HumTests/KaraokeItemTests.swift
git commit -m "feat: activeItemIndex binary search over KaraokeItem list"
```

---

### Task 4: `InstrumentalDotsView`

**Files:**
- Create: `Hum/Views/InstrumentalDotsView.swift`

No unit test — this is a SwiftUI view; its math (`dotFill`) is already covered. Verify by compilation in this task and visually in Task 7.

- [ ] **Step 1: Create the view**

Create `Hum/Views/InstrumentalDotsView.swift`:

```swift
import SwiftUI

/// Three dots whose individual fill amounts (0...1) drive their opacity.
struct DotsRow: View {
    let fills: [Double]      // exactly 3 values, 0...1
    let fontSize: CGFloat

    private var dotSize: CGFloat { max(8, fontSize * 0.32) }
    private var spacing: CGFloat { dotSize * 0.9 }
    private let dimOpacity: Double = 0.25

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3, id: \.self) { i in
                let fill = i < fills.count ? fills[i] : 0
                Circle()
                    .fill(Color.white)
                    .frame(width: dotSize, height: dotSize)
                    .opacity(dimOpacity + (1 - dimOpacity) * fill)
            }
        }
    }
}

/// Live instrumental indicator: observes MusicObserver and fills the dots as the
/// gap between `start` and `end` elapses. Updates at 60fps independently of the
/// enclosing (equatable) KaraokeView.
struct InstrumentalDotsView: View {
    let start: TimeInterval
    let end: TimeInterval
    let fontSize: CGFloat
    @ObservedObject var clock: MusicObserver

    private var progress: Double {
        guard end > start else { return 0 }
        return min(max((clock.playbackPosition - start) / (end - start), 0), 1)
    }

    var body: some View {
        DotsRow(fills: (0..<3).map { dotFill($0, progress: progress) }, fontSize: fontSize)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodegen generate && xcodebuild build -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' 2>&1 | tail -15`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Hum/Views/InstrumentalDotsView.swift Hum.xcodeproj
git commit -m "feat: InstrumentalDotsView + DotsRow progress indicator"
```

---

### Task 5: Render `[KaraokeItem]` in `KaraokeView`

**Files:**
- Modify: `Hum/Views/KaraokeView.swift`

This task rewrites `KaraokeView` to consume items instead of lines. The free `activeIndex` function at the top of the file is removed (superseded by `activeItemIndex` in `KaraokeItem.swift`).

- [ ] **Step 1: Replace the file contents**

Replace the entire contents of `Hum/Views/KaraokeView.swift` with:

```swift
import SwiftUI

struct KaraokeView: View, Equatable {
    let items: [KaraokeItem]
    let active: Int?
    let fontSize: CGFloat
    let musicObserver: MusicObserver

    // Equality intentionally excludes musicObserver: the dots subview observes it
    // directly, so KaraokeView's body only re-evaluates on structural changes.
    static func == (lhs: KaraokeView, rhs: KaraokeView) -> Bool {
        lhs.items == rhs.items && lhs.active == rhs.active && lhs.fontSize == rhs.fontSize
    }

    private var lineSpacing: CGFloat { 10 }
    private var lineHeight: CGFloat { ceil(fontSize * 1.25) + lineSpacing }

    /// Duration of the active-line appearance animation: time until the next item
    /// begins. For a line before an instrumental gap, the next item is that gap, so
    /// this is the line's natural duration (not the full gap) — fixing the pacing bug.
    private func lineDuration(for index: Int) -> TimeInterval {
        guard index + 1 < items.count else { return 0.9 }
        let available = items[index + 1].start - items[index].start
        return max(available, 0.3)
    }

    private func lineOpacity(for index: Int) -> Double {
        guard let active else { return 0.2 }
        switch abs(index - active) {
        case 0: return 0.3
        case 1: return 0.45
        case 2: return 0.28
        default: return 0.15
        }
    }

    private func lineScale(for index: Int) -> CGFloat {
        index == active ? 1.0 : 0.96
    }

    var body: some View {
        GeometryReader { geo in
            let vertPad = max(0, geo.size.height / 2 - lineHeight / 2)
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: lineSpacing) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            itemView(index: index, item: item)
                                .padding(.horizontal, 16)
                                .scaleEffect(lineScale(for: index), anchor: .leading)
                                .animation(.spring(duration: 0.45, bounce: 0.1), value: active)
                                .id(index)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, vertPad)
                }
                .onAppear {
                    if let a = active {
                        proxy.scrollTo(a, anchor: .center)
                    }
                }
                .onChange(of: active) { _, newActive in
                    if let newActive {
                        withAnimation(.spring(duration: 0.55, bounce: 0.12)) {
                            proxy.scrollTo(newActive, anchor: .center)
                        }
                    }
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.1),
                            .init(color: .black, location: 0.88),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    @ViewBuilder
    private func itemView(index: Int, item: KaraokeItem) -> some View {
        switch item {
        case .lyric(let line):
            ZStack(alignment: .leading) {
                Text(line.text)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(lineOpacity(for: index))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if index == active {
                    Text(line.text)
                        .customAttribute(EmphasisAttribute())
                        .font(.system(size: fontSize, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.asymmetric(
                            insertion: AnyTransition(TextTransition(duration: lineDuration(for: index))),
                            removal: .opacity.animation(.easeOut(duration: 0.15))
                        ))
                }
            }
        case .instrumental(let start, let end):
            Group {
                if index == active {
                    InstrumentalDotsView(start: start, end: end, fontSize: fontSize, clock: musicObserver)
                } else {
                    DotsRow(fills: [0, 0, 0], fontSize: fontSize)
                        .opacity(lineOpacity(for: index))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles (HumWindowView will still error — that's Task 6)**

Run: `xcodebuild build -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' 2>&1 | tail -20`
Expected: BUILD FAILS only in `HumWindowView.swift` (it still passes `lines:`/`active:` without `items:`/`musicObserver:`). `KaraokeView.swift` itself must report no errors.

- [ ] **Step 3: Commit**

```bash
git add Hum/Views/KaraokeView.swift
git commit -m "refactor: KaraokeView renders KaraokeItem list with instrumental dots"
```

---

### Task 6: Wire `HumWindowView` + remove obsolete tests

**Files:**
- Modify: `Hum/Views/HumWindowView.swift:7-9,52-58`
- Delete: `HumTests/KaraokeActiveLineTests.swift`

- [ ] **Step 1: Update `HumWindowView` to build items and pass them in**

In `Hum/Views/HumWindowView.swift`, replace the computed `activeLineIndex` (lines 7-9):

```swift
    private var activeLineIndex: Int? {
        activeIndex(in: lyricsState.lines, at: musicObserver.playbackPosition)
    }
```

with:

```swift
    private var items: [KaraokeItem] {
        buildItems(from: lyricsState.lines)
    }

    private var activeItem: Int? {
        activeItemIndex(in: items, at: musicObserver.playbackPosition)
    }
```

Then replace the `KaraokeView(...)` call (lines 53-58):

```swift
                    KaraokeView(
                        lines: lyricsState.lines,
                        active: activeLineIndex,
                        fontSize: lyricsState.fontSize
                    )
                    .equatable()
```

with:

```swift
                    KaraokeView(
                        items: items,
                        active: activeItem,
                        fontSize: lyricsState.fontSize,
                        musicObserver: musicObserver
                    )
                    .equatable()
```

- [ ] **Step 2: Delete the obsolete `activeIndex` tests**

The `activeIndex(in:at:)` function no longer exists, so its test file won't compile.

Run: `git rm HumTests/KaraokeActiveLineTests.swift`

(Coverage is preserved by `activeItemIndex` tests in `KaraokeItemTests.swift`.)

- [ ] **Step 3: Regenerate, build, and run the full test suite**

Run: `xcodegen generate && xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' 2>&1 | tail -25`
Expected: BUILD SUCCEEDED and TEST SUCCEEDED — `KaraokeItemTests`, `LRCParserTests`, `LyricsEngineTests`, `MusicObserverTests` all pass; no reference to the deleted file.

- [ ] **Step 4: Commit**

```bash
git add Hum/Views/HumWindowView.swift HumTests Hum.xcodeproj
git commit -m "feat: wire instrumental items + dots into HumWindowView"
```

---

### Task 7: Manual smoke test & tuning

**Files:** none (verification only).

- [ ] **Step 1: Build and run the app**

Run: `xcodebuild build -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED. Launch from Xcode (or the built `.app`).

- [ ] **Step 2: Verify against a song with a known instrumental gap**

Play a track in Apple Music that has a long instrumental break or intro and observe:
- The line *before* an instrumental break now animates at a natural pace (no more crawling/slowing). ✅ the original bug.
- During the break, three dots appear in the centered active slot, the upcoming line previewed dim below.
- The dots fill left-to-right (dot 1 → 2 → 3) in proportion to how much of the gap has elapsed, reaching full just as the next line begins.
- A long intro (first lyric ≥ 5s in) shows the dots before the first line.
- A song with only short gaps shows no dots and behaves as before.

- [ ] **Step 3: Tune constants if needed**

If the natural pace feels off or dots appear too often/rarely, adjust the constants at the top of `Hum/Views/KaraokeItem.swift` (`SEC_PER_CHAR`, `MIN_LINE`, `MAX_LINE`, `GAP_THRESHOLD`), rebuild, and re-observe. Commit any tuning:

```bash
git add Hum/Views/KaraokeItem.swift
git commit -m "tune: instrumental timing constants"
```

---

## Self-Review Notes

- **Spec coverage:** synthetic item model (Tasks 1-3, 5), pacing-bug fix via next-item-start duration (Task 5 `lineDuration`), dots view with 60fps independence (Task 4), intro + inter-line gap detection + threshold (Task 2), progress/fill math (Task 1), active-item resolution (Task 3), wiring (Task 6), testing + build note (all tasks). All covered.
- **Type consistency:** `KaraokeItem`, `naturalDuration(_:)`, `dotFill(_:progress:)`, `buildItems(from:)`, `activeItemIndex(in:at:)`, `InstrumentalDotsView(start:end:fontSize:clock:)`, `DotsRow(fills:fontSize:)`, `KaraokeView(items:active:fontSize:musicObserver:)` — used identically across tasks.
