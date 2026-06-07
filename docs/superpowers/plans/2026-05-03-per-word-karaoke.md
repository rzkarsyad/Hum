# Hum — Per-Word Karaoke Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace line-level TextTransition animation with per-word timing — each word lights up individually as the song plays through the line, using interpolated timestamps derived from line-level LRC data.

**Architecture:** Three sequential tasks — (1) add `WordToken` model and a testable `wordTokens(for:nextTimestamp:)` interpolation function (TDD); (2) create `WordFlowView.swift` with a custom `WordFlowLayout` (SwiftUI `Layout` protocol) and `WordFlowView` (per-word opacity animation); (3) simplify `KaraokeView` to use `WordFlowView` for the active line and delete the now-unused `TextEffects.swift`.

**Tech Stack:** SwiftUI `Layout` protocol (macOS 15+), Spring animation, XCTest

---

## File Map

| Path | Change |
|------|--------|
| `Hum/Models/WordToken.swift` | New: `WordToken` struct + `wordTokens(for:nextTimestamp:)` free function |
| `Hum/Views/WordFlowView.swift` | New: `WordFlowLayout` (custom Layout) + `WordFlowView` |
| `Hum/Views/KaraokeView.swift` | Rewrite: remove ZStack/TextTransition, use `WordFlowView` for active line |
| `Hum/Views/TextEffects.swift` | Delete: no longer used |
| `HumTests/WordTokenTests.swift` | New: 6 unit tests for `wordTokens` interpolation |

---

### Task 1: WordToken model + wordTokens (TDD)

**Files:**
- Create: `Hum/Models/WordToken.swift`
- Create: `HumTests/WordTokenTests.swift`

- [ ] **Step 1: Write failing tests in `HumTests/WordTokenTests.swift`**

```swift
import XCTest
@testable import Hum

final class WordTokenTests: XCTestCase {

    func test_singleWord_usesLineTimestamp() {
        let line = LyricLine(timestamp: 10.0, text: "Hello")
        let tokens = wordTokens(for: line, nextTimestamp: 12.0)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].text, "Hello")
        XCTAssertEqual(tokens[0].timestamp, 10.0, accuracy: 0.001)
    }

    func test_twoWords_splitsDurationEvenly() {
        let line = LyricLine(timestamp: 10.0, text: "Hello world")
        let tokens = wordTokens(for: line, nextTimestamp: 12.0)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].timestamp, 10.0, accuracy: 0.001)
        XCTAssertEqual(tokens[1].timestamp, 11.0, accuracy: 0.001)
    }

    func test_noNextTimestamp_uses5sFallback() {
        let line = LyricLine(timestamp: 10.0, text: "Hello world")
        let tokens = wordTokens(for: line, nextTimestamp: nil)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].timestamp, 10.0, accuracy: 0.001)
        XCTAssertEqual(tokens[1].timestamp, 12.5, accuracy: 0.001)
    }

    func test_timestampsAreMonotonicallyIncreasing() {
        let line = LyricLine(timestamp: 0.0, text: "one two three four")
        let tokens = wordTokens(for: line, nextTimestamp: 4.0)
        XCTAssertEqual(tokens.count, 4)
        for i in 1..<tokens.count {
            XCTAssertGreaterThan(tokens[i].timestamp, tokens[i - 1].timestamp)
        }
    }

    func test_emptyText_returnsEmpty() {
        let line = LyricLine(timestamp: 10.0, text: "")
        let tokens = wordTokens(for: line, nextTimestamp: 12.0)
        XCTAssertTrue(tokens.isEmpty)
    }

    func test_extraSpaces_filtered() {
        let line = LyricLine(timestamp: 10.0, text: "hello  world")
        let tokens = wordTokens(for: line, nextTimestamp: 12.0)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].text, "hello")
        XCTAssertEqual(tokens[1].text, "world")
    }
}
```

- [ ] **Step 2: Run to confirm compile error**

```bash
xcodegen generate
xcodebuild test -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/WordTokenTests 2>&1 | grep -E "(error:|FAIL|PASS)"
```

Expected: compile error — `WordToken` and `wordTokens` not found.

- [ ] **Step 3: Create `Hum/Models/WordToken.swift`**

```swift
import Foundation

struct WordToken {
    let text: String
    let timestamp: TimeInterval
}

func wordTokens(for line: LyricLine, nextTimestamp: TimeInterval?) -> [WordToken] {
    let words = line.text.components(separatedBy: " ").filter { !$0.isEmpty }
    guard !words.isEmpty else { return [] }

    let duration = nextTimestamp.map { max(0.1, $0 - line.timestamp) } ?? 5.0

    return words.enumerated().map { index, word in
        let t = line.timestamp + TimeInterval(index) / TimeInterval(words.count) * duration
        return WordToken(text: word, timestamp: t)
    }
}
```

**Math check:**
- 2 words, duration 2.0: word[0] = 10 + 0/2 × 2 = 10.0, word[1] = 10 + 1/2 × 2 = 11.0 ✓
- 2 words, no next (duration 5.0): word[1] = 10 + 1/2 × 5 = 12.5 ✓
- 4 words, duration 4.0: 0.0, 1.0, 2.0, 3.0 — monotonically increasing ✓

- [ ] **Step 4: Run tests to confirm all 6 pass**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/WordTokenTests 2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: All 6 PASS.

- [ ] **Step 5: Commit**

```bash
git add Hum/Models/WordToken.swift HumTests/WordTokenTests.swift Hum.xcodeproj/
git commit -m "feat: add WordToken model and wordTokens interpolation, tested"
```

---

### Task 2: WordFlowLayout + WordFlowView

**Files:**
- Create: `Hum/Views/WordFlowView.swift`

- [ ] **Step 1: Create `Hum/Views/WordFlowView.swift`**

```swift
import SwiftUI

struct WordFlowLayout: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(0.0) { $0 + $1.height + spacing } - (rows.isEmpty ? 0 : spacing)
        return CGSize(
            width: proposal.replacingUnspecifiedDimensions().width,
            height: max(0, height)
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: ProposedViewSize(bounds.size), subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for subview in row.subviews {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: .unspecified
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var subviews: [LayoutSubview] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        let available = proposal.replacingUnspecifiedDimensions().width

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needed = current.subviews.isEmpty ? size.width : current.width + spacing + size.width

            if needed > available && !current.subviews.isEmpty {
                rows.append(current)
                current = Row(subviews: [subview], width: size.width, height: size.height)
            } else {
                current.subviews.append(subview)
                current.width = needed
                current.height = max(current.height, size.height)
            }
        }

        if !current.subviews.isEmpty { rows.append(current) }
        return rows
    }
}

struct WordFlowView: View {
    let words: [WordToken]
    let playbackPosition: TimeInterval

    var body: some View {
        WordFlowLayout(spacing: 5) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, token in
                let isLit = playbackPosition >= token.timestamp
                Text(token.text)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .opacity(isLit ? 1.0 : 0.3)
                    .animation(.spring(duration: 0.15), value: isLit)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
git add Hum/Views/WordFlowView.swift Hum.xcodeproj/
git commit -m "feat: add WordFlowLayout and WordFlowView for per-word karaoke rendering"
```

---

### Task 3: KaraokeView rewrite + remove TextEffects

**Files:**
- Modify: `Hum/Views/KaraokeView.swift`
- Delete: `Hum/Views/TextEffects.swift`

- [ ] **Step 1: Replace full contents of `Hum/Views/KaraokeView.swift`**

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

    private var adjustedPosition: TimeInterval {
        musicObserver.playbackPosition + syncOffset
    }

    private var active: Int? {
        activeIndex(in: lines, at: adjustedPosition)
    }

    private func words(for index: Int) -> [WordToken] {
        let line = lines[index]
        let next = index + 1 < lines.count ? lines[index + 1].timestamp : nil
        return wordTokens(for: line, nextTimestamp: next)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Group {
                            if index == active {
                                WordFlowView(
                                    words: words(for: index),
                                    playbackPosition: adjustedPosition
                                )
                                .transition(.opacity.animation(.easeIn(duration: 0.15)))
                            } else {
                                Text(line.text)
                                    .font(.callout)
                                    .foregroundColor(.white)
                                    .opacity(0.3)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
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

- [ ] **Step 2: Delete `Hum/Views/TextEffects.swift`**

```bash
rm Hum/Views/TextEffects.swift
```

- [ ] **Step 3: Regenerate and build**

```bash
xcodegen generate
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `** BUILD SUCCEEDED **` — `TextEffects.swift` is gone and `KaraokeView` no longer references `EmphasisAttribute` or `TextTransition`.

- [ ] **Step 4: Run all tests**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(PASS|FAIL|error:|Test Suite.*passed|BUILD)"
```

Expected: All 24 tests PASS (18 original + 6 new `WordTokenTests`), `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add Hum/Views/KaraokeView.swift Hum.xcodeproj/
git rm Hum/Views/TextEffects.swift
git commit -m "feat: per-word karaoke animation with interpolated timing, remove TextEffects"
```
