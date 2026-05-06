# Lyrics Sync Accuracy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix lyric drift by correcting the AppleScript timing anchor in `MusicObserver`, add seek detection, and remove the now-unnecessary `syncOffset` manual adjustment from the UI.

**Architecture:** `MusicObserver.poll()` currently sets `baseDate = Date()` *after* AppleScript execution (~100ms late), causing a persistent timing bias. The fix records `prePollDate` before the call and uses that as the interpolation anchor. A new free function `isSeek(reported:interpolated:)` detects user seek events (position jump > 1.5s) and hard-resets the display immediately. The manual `syncOffset` stepper is removed from `StatusBarController`, `LyricsState`, and `HumWindowView`.

**Note on poll interval:** The spec suggested reducing poll from 500ms → 2000ms. This plan keeps 500ms — a 2s poll would cause noticeable delay detecting play/pause and track changes.

**Tech Stack:** Swift 5.9, SwiftUI+AppKit, XCTest, xcodegen

---

## File Map

| File | Action |
|------|--------|
| `Hum/StatusBar/StatusBarController.swift` | Remove offset label, stepper, `offsetChanged()`, syncOffset wiring |
| `Hum/LyricsEngine/LyricsState.swift` | Remove `syncOffset` property |
| `Hum/Views/HumWindowView.swift` | Remove `+ lyricsState.syncOffset` |
| `Hum/MusicObserver/MusicObserver.swift` | Add `isSeek()`, fix `baseDate` to use `prePollDate` |
| `HumTests/MusicObserverTests.swift` | Create — unit tests for `isSeek()` |

> **Task order matters for clean builds:** StatusBarController *uses* `syncOffset`, so it must be cleaned up before `syncOffset` is removed from `LyricsState`.

---

## Task 1: Remove sync offset UI from StatusBarController

**Files:**
- Modify: `Hum/StatusBar/StatusBarController.swift`

- [ ] **Step 1: Remove offset label and stepper from `buildMenu()`**

In `buildMenu()`, delete the following block (current lines 38–51):

```swift
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
```

After deletion, `buildMenu()` should start directly with the font size label.

- [ ] **Step 2: Remove the `offsetChanged(_:)` method**

Delete the entire method (current lines 108–113):

```swift
@objc private func offsetChanged(_ stepper: NSStepper) {
    lyricsState.syncOffset = stepper.doubleValue
    let val = stepper.doubleValue
    let sign = val >= 0 ? "+" : ""
    statusItem.menu?.item(withTag: 1)?.title = "Sync Offset: \(sign)\(val)s"
}
```

- [ ] **Step 3: Remove syncOffset wiring from `handleTrackChange(_:)`**

In `handleTrackChange(_:)`, delete these lines (currently around lines 181–189):

```swift
lyricsState.syncOffset = 0
```
```swift
if let stepper = statusItem.menu?.item(at: 1)?.view as? NSStepper {
    stepper.doubleValue = 0
}
statusItem.menu?.item(withTag: 1)?.title = "Sync Offset: +0.0s"
```

After removal, `handleTrackChange` should read:

```swift
private func handleTrackChange(_ track: Track?) async {
    guard let track else {
        lyricsState.lines = []
        lyricsState.noLyricsFound = false
        return
    }
    lyricsState.noLyricsFound = false
    if autoShowOnNewTrack {
        lyricsState.isManuallyHidden = false
    }
    let lines = await lyricsEngine.fetch(for: track)
    guard !Task.isCancelled else { return }
    lyricsState.lines = lines
    lyricsState.noLyricsFound = lines.isEmpty
}
```

- [ ] **Step 4: Build to confirm no errors**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Run tests**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(passed|failed|error:)"
```

Expected: all 18 tests pass.

- [ ] **Step 6: Commit**

```bash
git add Hum/StatusBar/StatusBarController.swift
git commit -m "refactor: remove sync offset stepper and wiring from StatusBarController"
```

---

## Task 2: Remove syncOffset from LyricsState and HumWindowView

**Files:**
- Modify: `Hum/LyricsEngine/LyricsState.swift`
- Modify: `Hum/Views/HumWindowView.swift`

- [ ] **Step 1: Remove `syncOffset` from LyricsState**

Replace the full file content of `Hum/LyricsEngine/LyricsState.swift`:

```swift
import Foundation

@MainActor
final class LyricsState: ObservableObject {
    @Published var lines: [LyricLine] = []
    @Published var isManuallyHidden: Bool = false
    @Published var noLyricsFound: Bool = false
    @Published var fontSize: CGFloat = {
        let stored = UserDefaults.standard.double(forKey: "humFontSize")
        return stored >= 12 ? CGFloat(stored) : 20
    }()
    @Published var isMinimized: Bool = false
}
```

- [ ] **Step 2: Remove syncOffset from `activeLineIndex` in HumWindowView**

In `Hum/Views/HumWindowView.swift`, replace lines 7–11:

```swift
private var activeLineIndex: Int? {
    activeIndex(
        in: lyricsState.lines,
        at: musicObserver.playbackPosition + lyricsState.syncOffset
    )
}
```

with:

```swift
private var activeLineIndex: Int? {
    activeIndex(in: lyricsState.lines, at: musicObserver.playbackPosition)
}
```

- [ ] **Step 3: Build to confirm no errors**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Run tests**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(passed|failed|error:)"
```

Expected: all 18 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Hum/LyricsEngine/LyricsState.swift Hum/Views/HumWindowView.swift
git commit -m "refactor: remove syncOffset from LyricsState and HumWindowView"
```

---

## Task 3: Fix MusicObserver timing + seek detection + unit tests

**Files:**
- Modify: `Hum/MusicObserver/MusicObserver.swift`
- Create: `HumTests/MusicObserverTests.swift`

- [ ] **Step 1: Write the failing test for `isSeek`**

Create `HumTests/MusicObserverTests.swift`:

```swift
import XCTest
@testable import Hum

final class MusicObserverTests: XCTestCase {

    func test_isSeekReturnsTrueWhenDiffExceedsThreshold() {
        XCTAssertTrue(isSeek(reported: 10.0, interpolated: 12.0))
    }

    func test_isSeekReturnsFalseWhenDiffWithinThreshold() {
        XCTAssertFalse(isSeek(reported: 10.0, interpolated: 10.3))
    }

    func test_isSeekReturnsFalseAtExactThreshold() {
        XCTAssertFalse(isSeek(reported: 10.0, interpolated: 11.5))
    }

    func test_isSeekHandlesBackwardSeek() {
        XCTAssertTrue(isSeek(reported: 5.0, interpolated: 10.0))
    }
}
```

- [ ] **Step 2: Register the new test file with xcodegen**

```bash
cd /Users/rzkarsyad/Documents/Codes/Hum && xcodegen generate 2>&1 | tail -5
```

Expected: `Wrote project to Hum.xcodeproj`

- [ ] **Step 3: Run test to verify it fails**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(MusicObserverTests|error:)"
```

Expected: compile error — `use of unresolved identifier 'isSeek'`

- [ ] **Step 4: Add `isSeek` free function to MusicObserver.swift**

At the top of `Hum/MusicObserver/MusicObserver.swift`, before the `import AppKit` line or directly before the class declaration, add:

```swift
func isSeek(reported: TimeInterval, interpolated: TimeInterval) -> Bool {
    abs(reported - interpolated) > 1.5
}
```

- [ ] **Step 5: Fix `poll()` to use `prePollDate` and call `isSeek`**

Replace the entire `poll()` method in `MusicObserver.swift`:

```swift
private func poll() {
    let prePollDate = Date()
    guard let result = runAppleScript(pollScript) else { return }
    let parts = result.components(separatedBy: "\t")

    switch parts.first {
    case "playing" where parts.count == 6:
        let track = Track(
            title: parts[1],
            artist: parts[2],
            album: parts[3],
            duration: TimeInterval(parts[5].replacingOccurrences(of: ",", with: "."))
        )
        let position = TimeInterval(parts[4].replacingOccurrences(of: ",", with: ".")) ?? 0
        if currentTrack != track { currentTrack = track }
        let interpolated = basePosition + prePollDate.timeIntervalSince(baseDate)
        if isSeek(reported: position, interpolated: interpolated) {
            playbackPosition = position
        }
        basePosition = position
        baseDate = prePollDate
        isPlaying = true
    case "paused":
        isPlaying = false
    default:
        isPlaying = false
        currentTrack = nil
        playbackPosition = 0
        basePosition = 0
    }
}
```

Key changes vs original:
- `let prePollDate = Date()` before the AppleScript call (was after)
- Seek detection: hard-reset `playbackPosition` only on jumps > 1.5s
- `baseDate = prePollDate` (was `baseDate = Date()` after execution)
- Removed unconditional `playbackPosition = position` — `interpolatePosition()` handles it at 60fps

- [ ] **Step 6: Run all tests**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(Test Suite|passed|failed|error:)" | tail -10
```

Expected: 22 tests pass (18 original + 4 new `MusicObserverTests`).

- [ ] **Step 7: Commit**

```bash
git add Hum/MusicObserver/MusicObserver.swift HumTests/MusicObserverTests.swift
git commit -m "fix: correct timing anchor in MusicObserver poll, add seek detection"
```

---

## Verification

After all tasks complete:

1. Open Xcode, run the Hum scheme on macOS
2. Play a song with LRCLIB lyrics in Apple Music → verify lyrics track correctly through the song (not just the start)
3. Seek to the middle of the song → lyrics should resync within ≤500ms
4. Pause → lyrics window hides; resume → window reappears
5. Confirm menu bar no longer shows "Sync Offset" label or stepper
6. Run full test suite: `xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(passed|failed)"`
