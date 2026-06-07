# Hum — UI Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Four improvements — better word timing via char-weighted interpolation, uniform font size, song title header, and a hide button with status bar restore toggle.

**Architecture:** Four sequential tasks — (1) update `wordTokens` to character-weighted + 10% buffer with updated TDD; (2) add `isManuallyHidden` to `LyricsState` and fix inactive font; (3) add song title header and hide button to `HumWindowView`, update window height; (4) wire `StatusBarController` with `CombineLatest3`, Show/Hide menu item, and auto-reset on track change.

**Tech Stack:** SwiftUI, Combine (`CombineLatest3`), XCTest

---

## File Map

| Path | Change |
|------|--------|
| `Hum/Models/WordToken.swift` | char-weighted formula with 10% buffer |
| `HumTests/WordTokenTests.swift` | update 3 tests + add 1 new char-weight test |
| `Hum/LyricsEngine/LyricsState.swift` | add `@Published var isManuallyHidden: Bool = false` |
| `Hum/Views/KaraokeView.swift` | inactive font `.callout` → `.title3` |
| `Hum/Views/HumWindowView.swift` | add header row: title + hide button; height 220→260 |
| `Hum/Window/WindowManager.swift` | height 220→260, restore only origin not size |
| `Hum/StatusBar/StatusBarController.swift` | CombineLatest3, "Hide/Show Lyrics" menu item, auto-reset |

---

### Task 1: Timing — char-weighted wordTokens (TDD)

**Files:**
- Modify: `Hum/Models/WordToken.swift`
- Modify: `HumTests/WordTokenTests.swift`

**New formula:**
```
effective_duration = duration × 0.8    (trim 10% at start + 10% at end)
start_offset       = duration × 0.1
total_chars        = sum of word.count for all words
cumulative[i]      = sum of word[j].count for j < i

word[i].timestamp = line.timestamp + start_offset + (cumulative[i] / total_chars) × effective_duration
```

- [ ] **Step 1: Update `HumTests/WordTokenTests.swift` with new expected values**

```swift
import XCTest
@testable import Hum

final class WordTokenTests: XCTestCase {

    func test_singleWord_usesLineTimestampPlusBuffer() {
        // duration=2.0, start_offset=0.2 → word[0] = 10.0 + 0.2 = 10.2
        let line = LyricLine(timestamp: 10.0, text: "Hello")
        let tokens = wordTokens(for: line, nextTimestamp: 12.0)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].text, "Hello")
        XCTAssertEqual(tokens[0].timestamp, 10.2, accuracy: 0.001)
    }

    func test_twoEqualWords_charWeightedWithBuffer() {
        // duration=2.0, start_offset=0.2, effective=1.6, "Hello"=5 "world"=5, total=10
        // word[0]: 10.0 + 0.2 + (0/10)*1.6 = 10.2
        // word[1]: 10.0 + 0.2 + (5/10)*1.6 = 11.0
        let line = LyricLine(timestamp: 10.0, text: "Hello world")
        let tokens = wordTokens(for: line, nextTimestamp: 12.0)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].timestamp, 10.2, accuracy: 0.001)
        XCTAssertEqual(tokens[1].timestamp, 11.0, accuracy: 0.001)
    }

    func test_noNextTimestamp_uses5sFallback() {
        // duration=5.0, start_offset=0.5, effective=4.0, "Hello"=5 "world"=5, total=10
        // word[0]: 10.0 + 0.5 + 0 = 10.5
        // word[1]: 10.0 + 0.5 + (5/10)*4.0 = 12.5
        let line = LyricLine(timestamp: 10.0, text: "Hello world")
        let tokens = wordTokens(for: line, nextTimestamp: nil)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].timestamp, 10.5, accuracy: 0.001)
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

    func test_longerWordGetsMoreTime() {
        // "hi"(2) + "world"(5) = 7 chars. duration=7.0 → start_offset=0.7, effective=5.6
        // word[0] ("hi"):    0.0 + 0.7 + (0/7)*5.6 = 0.7
        // word[1] ("world"): 0.0 + 0.7 + (2/7)*5.6 = 0.7 + 1.6 = 2.3
        // Even distribution would put word[1] at 3.5 — char-weight is earlier because "hi" is short
        let line = LyricLine(timestamp: 0.0, text: "hi world")
        let tokens = wordTokens(for: line, nextTimestamp: 7.0)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].timestamp, 0.7, accuracy: 0.001)
        XCTAssertEqual(tokens[1].timestamp, 2.3, accuracy: 0.001)
        XCTAssertLessThan(tokens[1].timestamp, 3.5) // earlier than even distribution
    }
}
```

- [ ] **Step 2: Run tests to confirm failures (old implementation)**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/WordTokenTests 2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: several FAIL (tests with new expected values don't match old formula). `test_timestampsAreMonotonicallyIncreasing`, `test_emptyText_returnsEmpty`, `test_extraSpaces_filtered` may still pass.

- [ ] **Step 3: Replace `Hum/Models/WordToken.swift` with new formula**

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
    let startOffset = duration * 0.1
    let effectiveDuration = duration * 0.8
    let totalChars = words.reduce(0) { $0 + $1.count }
    guard totalChars > 0 else { return [] }

    var cumulative = 0
    return words.map { word in
        let t = line.timestamp + startOffset + (Double(cumulative) / Double(totalChars)) * effectiveDuration
        cumulative += word.count
        return WordToken(text: word, timestamp: t)
    }
}
```

- [ ] **Step 4: Run tests to confirm all 7 pass**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/WordTokenTests 2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: All 7 PASS.

- [ ] **Step 5: Commit**

```bash
git add Hum/Models/WordToken.swift HumTests/WordTokenTests.swift
git commit -m "feat: char-weighted word timing with 10% start/end buffer"
```

---

### Task 2: Font size + LyricsState.isManuallyHidden

**Files:**
- Modify: `Hum/LyricsEngine/LyricsState.swift`
- Modify: `Hum/Views/KaraokeView.swift`

- [ ] **Step 1: Add `isManuallyHidden` to `Hum/LyricsEngine/LyricsState.swift`**

```swift
import Foundation

@MainActor
final class LyricsState: ObservableObject {
    @Published var lines: [LyricLine] = []
    @Published var syncOffset: TimeInterval = 0
    @Published var isManuallyHidden: Bool = false
}
```

- [ ] **Step 2: Update inactive font in `Hum/Views/KaraokeView.swift`**

Find the inactive `else` branch inside `ForEach`. Change `.font(.callout)` to `.font(.title3)`:

```swift
                        } else {
                            Text(line.text)
                                .font(.title3)
                                .foregroundColor(.white)
                                .opacity(0.3)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
```

- [ ] **Step 3: Build + run all tests**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(Test Suite.*passed|FAIL|error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`, all 24 tests PASS.

- [ ] **Step 4: Commit**

```bash
git add Hum/LyricsEngine/LyricsState.swift Hum/Views/KaraokeView.swift
git commit -m "feat: uniform title3 font size and isManuallyHidden in LyricsState"
```

---

### Task 3: HumWindowView header + WindowManager height

**Files:**
- Modify: `Hum/Views/HumWindowView.swift`
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
                HStack(alignment: .center) {
                    Text(musicObserver.currentTrack?.title ?? "")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
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
                .frame(height: 36)

                if !lyricsState.lines.isEmpty {
                    KaraokeView(
                        lines: lyricsState.lines,
                        musicObserver: musicObserver,
                        syncOffset: lyricsState.syncOffset
                    )
                }
            }
        }
        .frame(width: 320, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 2: Update `restoreOrSetDefaultPosition` in `Hum/Window/WindowManager.swift`**

Find and replace `restoreOrSetDefaultPosition()`:

```swift
    private func restoreOrSetDefaultPosition() {
        let size = CGSize(width: 320, height: 260)
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

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add Hum/Views/HumWindowView.swift Hum/Window/WindowManager.swift
git commit -m "feat: song title header, hide button, window height 260px"
```

---

### Task 4: StatusBarController wiring

**Files:**
- Modify: `Hum/StatusBar/StatusBarController.swift`

- [ ] **Step 1: Replace `Hum/StatusBar/StatusBarController.swift`**

```swift
import AppKit
import Combine

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()
    private var fetchTask: Task<Void, Never>?
    private let musicObserver: MusicObserver
    private let lyricsEngine: LyricsEngine
    private let lyricsState: LyricsState
    private let windowManager: WindowManager

    init(
        musicObserver: MusicObserver,
        lyricsEngine: LyricsEngine,
        lyricsState: LyricsState,
        windowManager: WindowManager
    ) {
        self.musicObserver = musicObserver
        self.lyricsEngine = lyricsEngine
        self.lyricsState = lyricsState
        self.windowManager = windowManager
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Hum")
        buildMenu()
        observe()
    }

    private func buildMenu() {
        let menu = NSMenu()

        let offsetLabel = NSMenuItem(title: "Sync Offset: +0.0s", action: nil, keyEquivalent: "")
        offsetLabel.tag = 1
        menu.addItem(offsetLabel)

        let stepperItem = NSMenuItem()
        let stepper = NSStepper()
        stepper.minValue = -5
        stepper.maxValue = 5
        stepper.increment = 0.5
        stepper.doubleValue = 0
        stepper.target = self
        stepper.action = #selector(offsetChanged(_:))
        stepper.frame = CGRect(x: 8, y: 0, width: 100, height: 22)
        stepperItem.view = stepper
        menu.addItem(stepperItem)

        menu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: "Hide Lyrics",
            action: #selector(toggleLyricsVisibility),
            keyEquivalent: ""
        )
        hideItem.tag = 2
        hideItem.target = self
        menu.addItem(hideItem)

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        loginItem.state = LaunchAtLoginManager.isEnabled ? .on : .off
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Quit Hum", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )

        statusItem.menu = menu
    }

    @objc private func offsetChanged(_ stepper: NSStepper) {
        lyricsState.syncOffset = stepper.doubleValue
        let val = stepper.doubleValue
        let sign = val >= 0 ? "+" : ""
        statusItem.menu?.item(withTag: 1)?.title = "Sync Offset: \(sign)\(val)s"
    }

    @objc private func toggleLaunchAtLogin(_ item: NSMenuItem) {
        LaunchAtLoginManager.setEnabled(!LaunchAtLoginManager.isEnabled)
        item.state = LaunchAtLoginManager.isEnabled ? .on : .off
    }

    @objc private func toggleLyricsVisibility() {
        lyricsState.isManuallyHidden = !lyricsState.isManuallyHidden
    }

    private func observe() {
        musicObserver.$currentTrack
            .removeDuplicates()
            .sink { [weak self] track in
                guard let self else { return }
                self.fetchTask?.cancel()
                self.fetchTask = Task { @MainActor in await self.handleTrackChange(track) }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(musicObserver.$isPlaying, lyricsState.$lines, lyricsState.$isManuallyHidden)
            .sink { [weak self] isPlaying, lines, isHidden in
                guard let self else { return }
                if isPlaying && !lines.isEmpty && !isHidden {
                    self.windowManager.show()
                } else {
                    self.windowManager.hide()
                }
            }
            .store(in: &cancellables)

        lyricsState.$isManuallyHidden
            .sink { [weak self] isHidden in
                self?.statusItem.menu?.item(withTag: 2)?.title = isHidden ? "Show Lyrics" : "Hide Lyrics"
            }
            .store(in: &cancellables)
    }

    private func handleTrackChange(_ track: Track?) async {
        guard let track else { lyricsState.lines = []; return }
        lyricsState.syncOffset = 0
        lyricsState.isManuallyHidden = false
        if let stepper = statusItem.menu?.item(at: 1)?.view as? NSStepper {
            stepper.doubleValue = 0
        }
        statusItem.menu?.item(withTag: 1)?.title = "Sync Offset: +0.0s"
        let lines = await lyricsEngine.fetch(for: track)
        guard !Task.isCancelled else { return }
        lyricsState.lines = lines
    }
}
```

- [ ] **Step 2: Build + run all tests**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(Test Suite.*passed|FAIL|error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`, all 24 tests PASS.

- [ ] **Step 3: Commit**

```bash
git add Hum/StatusBar/StatusBarController.swift
git commit -m "feat: Show/Hide Lyrics menu, CombineLatest3 visibility, auto-reset on track change"
```
