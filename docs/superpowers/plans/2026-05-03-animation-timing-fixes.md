# Hum — Animation & Timing Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix four issues: remove start-offset from word timing, add artist name to header, uniform bold font, and replace ZStack+TextTransition with single-layer spring animation (no double effect, sequential appearance).

**Architecture:** Three sequential tasks — (1) TDD timing fix (remove start offset, keep 10% end buffer); (2) UI polish (artist name, header height 52px, window 276px, inactive bold font); (3) animation overhaul (single Text layer with opacity+spring, delete TextEffects.swift).

**Tech Stack:** SwiftUI, XCTest

---

## File Map

| Path | Change |
|------|--------|
| `Hum/Models/WordToken.swift` | Remove start offset, `effectiveDuration = duration * 0.9` |
| `HumTests/WordTokenTests.swift` | Update 4 test expected values |
| `Hum/Views/HumWindowView.swift` | Add artist text, header 52px, window 276px |
| `Hum/Views/KaraokeView.swift` | Inactive font `.title3` → `.title3.bold()` |
| `Hum/Window/WindowManager.swift` | Size `(320, 260)` → `(320, 276)` |
| `Hum/Views/WordFlowView.swift` | Replace ZStack with single Text + spring animation |
| `Hum/Views/TextEffects.swift` | Delete — no longer referenced |

---

### Task 1: Timing fix (TDD)

**Files:**
- Modify: `Hum/Models/WordToken.swift`
- Modify: `HumTests/WordTokenTests.swift`

- [ ] **Step 1: Update `HumTests/WordTokenTests.swift` with new expected values**

```swift
import XCTest
@testable import Hum

final class WordTokenTests: XCTestCase {

    func test_singleWord_usesLineTimestamp() {
        // startOffset=0, effective=1.8 → word[0] = 10.0 + (0/5)*1.8 = 10.0
        let line = LyricLine(timestamp: 10.0, text: "Hello")
        let tokens = wordTokens(for: line, nextTimestamp: 12.0)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].text, "Hello")
        XCTAssertEqual(tokens[0].timestamp, 10.0, accuracy: 0.001)
    }

    func test_twoEqualWords_charWeighted() {
        // duration=2.0, effective=1.8, "Hello"(5)+"world"(5)=10 total
        // word[0]: 10.0 + (0/10)*1.8 = 10.0
        // word[1]: 10.0 + (5/10)*1.8 = 10.9
        let line = LyricLine(timestamp: 10.0, text: "Hello world")
        let tokens = wordTokens(for: line, nextTimestamp: 12.0)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].timestamp, 10.0, accuracy: 0.001)
        XCTAssertEqual(tokens[1].timestamp, 10.9, accuracy: 0.001)
    }

    func test_noNextTimestamp_uses5sFallback() {
        // duration=5.0, effective=4.5, "Hello"(5)+"world"(5)=10 total
        // word[0]: 10.0 + (0/10)*4.5 = 10.0
        // word[1]: 10.0 + (5/10)*4.5 = 12.25
        let line = LyricLine(timestamp: 10.0, text: "Hello world")
        let tokens = wordTokens(for: line, nextTimestamp: nil)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].timestamp, 10.0, accuracy: 0.001)
        XCTAssertEqual(tokens[1].timestamp, 12.25, accuracy: 0.001)
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

    func test_longerWordGetsMoreTime() {
        // "hi"(2)+"world"(5)=7 total. duration=7.0, effective=6.3
        // word[0] ("hi"):    0.0 + (0/7)*6.3 = 0.0
        // word[1] ("world"): 0.0 + (2/7)*6.3 = 1.8
        // Even distribution puts word[1] at 3.5 — char-weight is earlier
        let line = LyricLine(timestamp: 0.0, text: "hi world")
        let tokens = wordTokens(for: line, nextTimestamp: 7.0)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].timestamp, 0.0, accuracy: 0.001)
        XCTAssertEqual(tokens[1].timestamp, 1.8, accuracy: 0.001)
        XCTAssertLessThan(tokens[1].timestamp, 3.5)
    }
}
```

- [ ] **Step 2: Run to confirm failures (old formula has startOffset)**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/WordTokenTests 2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: several FAIL — `test_singleWord`, `test_twoEqualWords`, `test_noNextTimestamp`, `test_longerWordGetsMoreTime` have new expected values.

- [ ] **Step 3: Update `Hum/Models/WordToken.swift`**

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
    let effectiveDuration = duration * 0.9
    let totalChars = words.reduce(0) { $0 + $1.count }
    guard totalChars > 0 else { return [] }

    var cumulative = 0
    return words.map { word in
        let t = line.timestamp + (Double(cumulative) / Double(totalChars)) * effectiveDuration
        cumulative += word.count
        return WordToken(text: word, timestamp: t)
    }
}
```

- [ ] **Step 4: Run to confirm all 7 pass**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/WordTokenTests 2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: All 7 PASS.

- [ ] **Step 5: Commit**

```bash
git add Hum/Models/WordToken.swift HumTests/WordTokenTests.swift
git commit -m "feat: remove start offset from word timing, 10% end buffer only"
```

---

### Task 2: Artist name + font weight + window height

**Files:**
- Modify: `Hum/Views/HumWindowView.swift`
- Modify: `Hum/Views/KaraokeView.swift`
- Modify: `Hum/Window/WindowManager.swift`

- [ ] **Step 1: Replace `Hum/Views/HumWindowView.swift`**

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
        .frame(width: 320, height: 276)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 2: Update inactive font in `Hum/Views/KaraokeView.swift`**

Find the inactive `else` branch. Change `.font(.title3)` to `.font(.title3.bold())`:

```swift
                        } else {
                            Text(line.text)
                                .font(.title3.bold())
                                .foregroundColor(.white)
                                .opacity(0.3)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
```

- [ ] **Step 3: Update size in `Hum/Window/WindowManager.swift`**

Find `restoreOrSetDefaultPosition()`. Change `CGSize(width: 320, height: 260)` to `CGSize(width: 320, height: 276)` in both the restore and default paths:

```swift
    private func restoreOrSetDefaultPosition() {
        let size = CGSize(width: 320, height: 276)
        if let saved = UserDefaults.standard.string(forKey: "windowFrame") {
            let oldFrame = NSRectFromString(saved)
            if oldFrame != .zero {
                panel.setFrame(CGRect(origin: oldFrame.origin, size: size), display: false)
                return
            }
        }
        guard let screen = NSScreen.main else { return }
        let origin = CGPoint(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.minY + 60
        )
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
    }
```

- [ ] **Step 4: Build to verify**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add Hum/Views/HumWindowView.swift Hum/Views/KaraokeView.swift Hum/Window/WindowManager.swift
git commit -m "feat: artist name in header, bold inactive font, window height 276px"
```

---

### Task 3: Single-layer spring animation + remove TextEffects

**Files:**
- Modify: `Hum/Views/WordFlowView.swift`
- Delete: `Hum/Views/TextEffects.swift`

- [ ] **Step 1: Replace `WordFlowView` struct in `Hum/Views/WordFlowView.swift`**

Keep `WordFlowLayout` unchanged. Only replace the `WordFlowView` struct (lines 62–90):

```swift
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
                    .offset(y: isLit ? 0 : 3)
                    .animation(.spring(duration: 0.2, bounce: 0.3), value: isLit)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

Changes from current:
- ZStack with base+lit layers → single `Text` view
- No more `EmphasisAttribute` or `TextTransition` references
- `opacity` and `offset(y:)` animated together via `.spring(duration: 0.2, bounce: 0.3)`

- [ ] **Step 2: Delete `Hum/Views/TextEffects.swift`**

```bash
rm Hum/Views/TextEffects.swift
```

- [ ] **Step 3: Regenerate and build**

```bash
xcodegen generate
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED` — no references to `TextEffects` anywhere.

- [ ] **Step 4: Run all tests**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(Test Suite.*passed|FAIL|error:|BUILD)"
```

Expected: All 24 tests PASS, `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add Hum/Views/WordFlowView.swift Hum.xcodeproj/
git rm Hum/Views/TextEffects.swift
git commit -m "feat: single-layer spring animation per word, remove TextEffects"
```
