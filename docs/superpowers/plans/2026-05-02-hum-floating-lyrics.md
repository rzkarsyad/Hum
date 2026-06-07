# Hum — Floating Lyrics App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app that displays real-time karaoke-style floating lyrics synced with Apple Music playback.

**Architecture:** Single Xcode app target with four bounded modules — `MusicObserver` (AppleScript polling), `LyricsEngine` (fetch + cache + parse), `KaraokeView` (SwiftUI karaoke rendering), and `WindowManager` (AppKit NSPanel floating window). A `StatusBarController` wires them together via `NSStatusItem`.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit, LRCLIB API, xcodegen, XCTest, macOS 13+

---

## File Map

| Path | Responsibility |
|------|---------------|
| `project.yml` | xcodegen config — app target, test target, entitlements |
| `Hum/Info.plist` | Bundle config: LSUIElement, usage descriptions |
| `Hum/Hum.entitlements` | App sandbox off, apple-events, network client |
| `Hum/HumApp.swift` | `@main` App entry point, injects AppDelegate |
| `Hum/AppDelegate.swift` | Creates and wires all components |
| `Hum/Models/Track.swift` | `Track` struct — title, artist, album |
| `Hum/Models/LyricLine.swift` | `LyricLine` struct — timestamp, text |
| `Hum/LyricsEngine/LyricsSource.swift` | `LyricsSource` protocol for testability |
| `Hum/LyricsEngine/LRCParser.swift` | Parses `.lrc` string → `[LyricLine]` |
| `Hum/LyricsEngine/LRCLIBSource.swift` | Fetches synced lyrics from lrclib.net |
| `Hum/LyricsEngine/MusicKitSource.swift` | MusicKit stub (public API lacks synced lyrics) |
| `Hum/LyricsEngine/LyricsEngine.swift` | Fetches with MusicKit→LRCLIB fallback, in-memory cache |
| `Hum/LyricsEngine/LyricsState.swift` | `@Published` lyrics lines + sync offset |
| `Hum/MusicObserver/MusicObserver.swift` | Polls Apple Music via AppleScript at 500ms |
| `Hum/Views/VibrancyView.swift` | `NSViewRepresentable` for vibrancy dark background |
| `Hum/Views/KaraokeView.swift` | Scrolling lyrics with animated active line highlight |
| `Hum/Views/HumWindowView.swift` | Root SwiftUI view inside the floating panel |
| `Hum/Window/WindowManager.swift` | `NSPanel` always-on-top, drag, persist position |
| `Hum/StatusBar/StatusBarController.swift` | `NSStatusItem`, menu, Combine observers |
| `HumTests/LRCParserTests.swift` | Unit tests for `.lrc` parser |
| `HumTests/LyricsEngineTests.swift` | Unit tests for fetch + fallback + cache |
| `HumTests/KaraokeActiveLineTests.swift` | Unit tests for active line computation |

---

### Task 1: Project Bootstrap

**Files:**
- Create: `project.yml`
- Create: `Hum/Info.plist`
- Create: `Hum/Hum.entitlements`
- Create: `Hum/HumApp.swift` (shell to keep the target non-empty)

- [ ] **Step 1: Install xcodegen if needed**

```bash
which xcodegen || brew install xcodegen
```

Expected: path printed or xcodegen installed successfully.

- [ ] **Step 2: Create `project.yml`**

```yaml
name: Hum
options:
  bundleIdPrefix: com.rzkarsyad
  deploymentTarget:
    macOS: "13.0"
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
        CODE_SIGNING_ALLOWED: "NO"
    entitlements:
      path: Hum/Hum.entitlements
      properties:
        com.apple.security.app-sandbox: false
        com.apple.security.automation.apple-events: true
        com.apple.security.network.client: true
  HumTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - HumTests
    dependencies:
      - target: Hum
    settings:
      base:
        MACOSX_DEPLOYMENT_TARGET: "13.0"
        CODE_SIGNING_ALLOWED: "NO"
```

- [ ] **Step 3: Create `Hum/Info.plist`**

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
</dict>
</plist>
```

- [ ] **Step 4: Create `Hum/Hum.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 5: Create shell `Hum/HumApp.swift` so the target has a Swift source**

```swift
import SwiftUI

@main
struct HumApp: App {
    var body: some Scene {
        Settings { EmptyView() }
    }
}
```

- [ ] **Step 6: Create source directories, generate project, verify build**

```bash
mkdir -p Hum/Models Hum/MusicObserver Hum/LyricsEngine Hum/Views Hum/Window Hum/StatusBar
mkdir -p HumTests
xcodegen generate
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | tail -3
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 7: Init git and commit**

```bash
git init
git add project.yml Hum/ HumTests/ Hum.xcodeproj/
git commit -m "feat: bootstrap Hum Xcode project with xcodegen"
```

---

### Task 2: Data Models

**Files:**
- Create: `Hum/Models/Track.swift`
- Create: `Hum/Models/LyricLine.swift`

- [ ] **Step 1: Create `Hum/Models/Track.swift`**

```swift
struct Track: Equatable, Hashable {
    let title: String
    let artist: String
    let album: String
}
```

- [ ] **Step 2: Create `Hum/Models/LyricLine.swift`**

```swift
struct LyricLine: Equatable {
    let timestamp: TimeInterval
    let text: String
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add Hum/Models/
git commit -m "feat: add Track and LyricLine models"
```

---

### Task 3: LRC Parser (TDD)

**Files:**
- Create: `Hum/LyricsEngine/LRCParser.swift`
- Create: `HumTests/LRCParserTests.swift`

- [ ] **Step 1: Write failing tests in `HumTests/LRCParserTests.swift`**

```swift
import XCTest
@testable import Hum

final class LRCParserTests: XCTestCase {

    func test_parsesStandardTimestamps() {
        let lrc = "[00:12.34] Hello world\n[00:15.67] Second line"
        let lines = LRCParser.parse(lrc)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].timestamp, 12.34, accuracy: 0.001)
        XCTAssertEqual(lines[0].text, "Hello world")
        XCTAssertEqual(lines[1].timestamp, 15.67, accuracy: 0.001)
    }

    func test_parsesMillisecondTimestamps() {
        let lrc = "[01:23.456] Three digit fraction"
        let lines = LRCParser.parse(lrc)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].timestamp, 83.456, accuracy: 0.001)
    }

    func test_skipsMetadataLines() {
        let lrc = "[ti:Song Title]\n[ar:Artist]\n[00:01.00] Actual lyric"
        let lines = LRCParser.parse(lrc)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].text, "Actual lyric")
    }

    func test_skipsEmptyTextLines() {
        let lrc = "[00:01.00] \n[00:02.00] Real line"
        let lines = LRCParser.parse(lrc)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].text, "Real line")
    }

    func test_sortsLinesByTimestamp() {
        let lrc = "[00:15.00] Second\n[00:05.00] First"
        let lines = LRCParser.parse(lrc)
        XCTAssertEqual(lines[0].text, "First")
        XCTAssertEqual(lines[1].text, "Second")
    }

    func test_returnsEmptyForEmptyInput() {
        XCTAssertTrue(LRCParser.parse("").isEmpty)
    }

    func test_parsesLargeMinutes() {
        let lrc = "[123:45.67] Long track line"
        let lines = LRCParser.parse(lrc)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].timestamp, 123 * 60 + 45.67, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail (compile error)**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/LRCParserTests 2>&1 | grep -E "(error:|FAIL|PASS|BUILD)"
```

Expected: compile error — `LRCParser` not found.

- [ ] **Step 3: Create `Hum/LyricsEngine/LRCParser.swift`**

```swift
import Foundation

struct LRCParser {
    static func parse(_ lrc: String) -> [LyricLine] {
        lrc.components(separatedBy: "\n")
            .compactMap { parseLine($0) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private static func parseLine(_ line: String) -> LyricLine? {
        let pattern = #"^\[(\d{1,3}):(\d{2})\.(\d{2,3})\](.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges == 5 else { return nil }

        let minutes = Double(extract(line, match.range(at: 1))) ?? 0
        let seconds = Double(extract(line, match.range(at: 2))) ?? 0
        let fractionStr = extract(line, match.range(at: 3))
        let fraction = Double(fractionStr) ?? 0
        let divisor = fractionStr.count == 3 ? 1000.0 : 100.0
        let text = extract(line, match.range(at: 4)).trimmingCharacters(in: .whitespaces)

        guard !text.isEmpty else { return nil }

        return LyricLine(timestamp: minutes * 60 + seconds + fraction / divisor, text: text)
    }

    private static func extract(_ string: String, _ range: NSRange) -> String {
        guard let range = Range(range, in: string) else { return "" }
        return String(string[range])
    }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/LRCParserTests 2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: All 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Hum/LyricsEngine/LRCParser.swift HumTests/LRCParserTests.swift
git commit -m "feat: add LRC parser with full test coverage"
```

---

### Task 4: Lyrics Sources

**Files:**
- Create: `Hum/LyricsEngine/LyricsSource.swift`
- Create: `Hum/LyricsEngine/LRCLIBSource.swift`
- Create: `Hum/LyricsEngine/MusicKitSource.swift`

- [ ] **Step 1: Create `Hum/LyricsEngine/LyricsSource.swift`**

```swift
protocol LyricsSource {
    func fetchSyncedLyrics(for track: Track) async -> String?
}
```

- [ ] **Step 2: Create `Hum/LyricsEngine/LRCLIBSource.swift`**

```swift
import Foundation

struct LRCLIBSource: LyricsSource {
    func fetchSyncedLyrics(for track: Track) async -> String? {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album)
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Hum macOS app", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let json = try? JSONDecoder().decode(LRCLIBResponse.self, from: data) else { return nil }

        return json.syncedLyrics
    }
}

private struct LRCLIBResponse: Decodable {
    let syncedLyrics: String?
}
```

- [ ] **Step 3: Create `Hum/LyricsEngine/MusicKitSource.swift`**

```swift
// MusicKit's public API exposes only plain-text Song.lyrics, not timestamped lyrics.
// Karaoke sync requires timestamps, so this always returns nil.
// Preserved so the fallback chain is ready if Apple opens the synced lyrics API.
struct MusicKitSource: LyricsSource {
    func fetchSyncedLyrics(for track: Track) async -> String? { nil }
}
```

- [ ] **Step 4: Build to verify**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add Hum/LyricsEngine/LyricsSource.swift Hum/LyricsEngine/LRCLIBSource.swift Hum/LyricsEngine/MusicKitSource.swift
git commit -m "feat: add LyricsSource protocol, LRCLIBSource, and MusicKitSource stub"
```

---

### Task 5: LyricsEngine (TDD)

**Files:**
- Create: `Hum/LyricsEngine/LyricsEngine.swift`
- Create: `HumTests/LyricsEngineTests.swift`

- [ ] **Step 1: Write failing tests in `HumTests/LyricsEngineTests.swift`**

```swift
import XCTest
@testable import Hum

final class LyricsEngineTests: XCTestCase {

    private struct MockSource: LyricsSource {
        let result: String?
        func fetchSyncedLyrics(for track: Track) async -> String? { result }
    }

    private let track = Track(title: "Test", artist: "Artist", album: "Album")
    private let sampleLRC = "[00:01.00] Hello\n[00:02.00] World"

    func test_returnsParsedLinesOnSuccess() async {
        let engine = LyricsEngine(primary: MockSource(result: sampleLRC), fallback: MockSource(result: nil))
        let lines = await engine.fetch(for: track)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].text, "Hello")
    }

    func test_fallsBackWhenPrimaryReturnsNil() async {
        let engine = LyricsEngine(primary: MockSource(result: nil), fallback: MockSource(result: sampleLRC))
        let lines = await engine.fetch(for: track)
        XCTAssertEqual(lines.count, 2)
    }

    func test_returnsEmptyWhenBothSourcesFail() async {
        let engine = LyricsEngine(primary: MockSource(result: nil), fallback: MockSource(result: nil))
        let lines = await engine.fetch(for: track)
        XCTAssertTrue(lines.isEmpty)
    }

    func test_cachesPreviousResult() async {
        var callCount = 0
        struct CountingSource: LyricsSource {
            let onCall: () -> Void
            func fetchSyncedLyrics(for track: Track) async -> String? {
                onCall()
                return "[00:01.00] Cached"
            }
        }
        let engine = LyricsEngine(primary: CountingSource { callCount += 1 }, fallback: MockSource(result: nil))
        _ = await engine.fetch(for: track)
        _ = await engine.fetch(for: track)
        XCTAssertEqual(callCount, 1)
    }

    func test_fetchesAgainForDifferentTrack() async {
        var callCount = 0
        struct CountingSource: LyricsSource {
            let onCall: () -> Void
            func fetchSyncedLyrics(for track: Track) async -> String? {
                onCall()
                return "[00:01.00] Line"
            }
        }
        let engine = LyricsEngine(primary: CountingSource { callCount += 1 }, fallback: MockSource(result: nil))
        _ = await engine.fetch(for: Track(title: "A", artist: "B", album: "C"))
        _ = await engine.fetch(for: Track(title: "X", artist: "Y", album: "Z"))
        XCTAssertEqual(callCount, 2)
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail (compile error)**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/LyricsEngineTests 2>&1 | grep -E "(error:|FAIL|PASS|BUILD)"
```

Expected: compile error — `LyricsEngine` not found.

- [ ] **Step 3: Create `Hum/LyricsEngine/LyricsEngine.swift`**

```swift
import Foundation

final class LyricsEngine {
    private let primary: any LyricsSource
    private let fallback: any LyricsSource
    private var cache: [Track: [LyricLine]] = [:]

    init(primary: any LyricsSource = MusicKitSource(), fallback: any LyricsSource = LRCLIBSource()) {
        self.primary = primary
        self.fallback = fallback
    }

    func fetch(for track: Track) async -> [LyricLine] {
        if let cached = cache[track] { return cached }

        let lrc = await primary.fetchSyncedLyrics(for: track)
            ?? (await fallback.fetchSyncedLyrics(for: track))

        let lines = lrc.map { LRCParser.parse($0) } ?? []
        cache[track] = lines
        return lines
    }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/LyricsEngineTests 2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Hum/LyricsEngine/LyricsEngine.swift HumTests/LyricsEngineTests.swift
git commit -m "feat: add LyricsEngine with fallback and cache, tested"
```

---

### Task 6: MusicObserver

**Files:**
- Create: `Hum/MusicObserver/MusicObserver.swift`

- [ ] **Step 1: Create `Hum/MusicObserver/MusicObserver.swift`**

```swift
import AppKit
import Combine

@MainActor
final class MusicObserver: ObservableObject {
    @Published private(set) var currentTrack: Track? = nil
    @Published private(set) var playbackPosition: TimeInterval = 0
    @Published private(set) var isPlaying: Bool = false

    private var timer: Timer?

    func start() {
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        guard let result = runAppleScript(pollScript) else { return }
        let parts = result.components(separatedBy: "\t")

        switch parts.first {
        case "playing" where parts.count == 5:
            let track = Track(title: parts[1], artist: parts[2], album: parts[3])
            let position = TimeInterval(parts[4]) ?? 0
            if currentTrack != track { currentTrack = track }
            playbackPosition = position
            isPlaying = true
        case "paused":
            isPlaying = false
        default:
            isPlaying = false
            currentTrack = nil
            playbackPosition = 0
        }
    }

    private let pollScript = """
        tell application "System Events"
            if not (exists process "Music") then return "not_running"
        end tell
        tell application "Music"
            if player state is playing then
                set t to current track
                return "playing\t" & (name of t) & "\t" & (artist of t) & "\t" & (album of t) & "\t" & (player position as string)
            else if player state is paused then
                return "paused"
            else
                return "stopped"
            end if
        end tell
        """

    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return result.stringValue
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add Hum/MusicObserver/MusicObserver.swift
git commit -m "feat: add MusicObserver — polls Apple Music via AppleScript at 500ms"
```

---

### Task 7: VibrancyView + KaraokeView (TDD for active line)

**Files:**
- Create: `Hum/Views/VibrancyView.swift`
- Create: `Hum/Views/KaraokeView.swift`
- Create: `HumTests/KaraokeActiveLineTests.swift`

- [ ] **Step 1: Write failing tests in `HumTests/KaraokeActiveLineTests.swift`**

```swift
import XCTest
@testable import Hum

final class KaraokeActiveLineTests: XCTestCase {

    private func lines(_ timestamps: [Double]) -> [LyricLine] {
        timestamps.enumerated().map { LyricLine(timestamp: $0.element, text: "Line \($0.offset)") }
    }

    func test_returnsNilBeforeFirstLine() {
        XCTAssertNil(activeIndex(in: lines([5, 10, 15]), at: 3))
    }

    func test_returnsFirstLineAtExactTimestamp() {
        XCTAssertEqual(activeIndex(in: lines([5, 10, 15]), at: 5), 0)
    }

    func test_returnsLastLineBeforePosition() {
        XCTAssertEqual(activeIndex(in: lines([5, 10, 15]), at: 12), 1)
    }

    func test_returnsLastLineWhenPastAllLines() {
        XCTAssertEqual(activeIndex(in: lines([5, 10, 15]), at: 99), 2)
    }

    func test_returnsNilForEmptyLines() {
        XCTAssertNil(activeIndex(in: [], at: 10))
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail (compile error)**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/KaraokeActiveLineTests 2>&1 | grep -E "(error:|FAIL|PASS)"
```

Expected: compile error — `activeIndex` not found.

- [ ] **Step 3: Create `Hum/Views/VibrancyView.swift`**

```swift
import SwiftUI
import AppKit

struct VibrancyView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
```

- [ ] **Step 4: Create `Hum/Views/KaraokeView.swift`**

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
                VStack(alignment: .center, spacing: 10) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line.text)
                            .font(index == active ? .title3.bold() : .callout)
                            .foregroundColor(.white)
                            .opacity(index == active ? 1.0 : 0.45)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .id(index)
                    }
                }
                .padding(.vertical, 24)
            }
            .onChange(of: active) { idx in
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

- [ ] **Step 5: Run tests to confirm they pass**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/KaraokeActiveLineTests 2>&1 | grep -E "(PASS|FAIL|error:)"
```

Expected: All 5 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Hum/Views/VibrancyView.swift Hum/Views/KaraokeView.swift HumTests/KaraokeActiveLineTests.swift
git commit -m "feat: add VibrancyView and KaraokeView with tested activeIndex logic"
```

---

### Task 8: LyricsState + HumWindowView + WindowManager

**Files:**
- Create: `Hum/LyricsEngine/LyricsState.swift`
- Create: `Hum/Views/HumWindowView.swift`
- Create: `Hum/Window/WindowManager.swift`

- [ ] **Step 1: Create `Hum/LyricsEngine/LyricsState.swift`**

```swift
import Foundation

@MainActor
final class LyricsState: ObservableObject {
    @Published var lines: [LyricLine] = []
    @Published var syncOffset: TimeInterval = 0
}
```

- [ ] **Step 2: Create `Hum/Views/HumWindowView.swift`**

```swift
import SwiftUI

struct HumWindowView: View {
    @ObservedObject var lyricsState: LyricsState
    @ObservedObject var musicObserver: MusicObserver

    var body: some View {
        ZStack {
            VibrancyView()
            if !lyricsState.lines.isEmpty {
                KaraokeView(
                    lines: lyricsState.lines,
                    musicObserver: musicObserver,
                    syncOffset: lyricsState.syncOffset
                )
            }
        }
        .frame(width: 320, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 3: Create `Hum/Window/WindowManager.swift`**

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
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "windowFrame")
    }

    private func restoreOrSetDefaultPosition() {
        if let saved = UserDefaults.standard.string(forKey: "windowFrame") {
            let frame = NSRectFromString(saved)
            if frame != .zero { panel.setFrame(frame, display: false); return }
        }
        guard let screen = NSScreen.main else { return }
        let size = CGSize(width: 320, height: 220)
        let origin = CGPoint(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.minY + 60
        )
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
    }
}

private final class FloatingPanel: NSPanel {
    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless], backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

- [ ] **Step 4: Build to verify**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add Hum/LyricsEngine/LyricsState.swift Hum/Views/HumWindowView.swift Hum/Window/WindowManager.swift
git commit -m "feat: add LyricsState, HumWindowView, and floating WindowManager"
```

---

### Task 9: StatusBarController

**Files:**
- Create: `Hum/StatusBar/StatusBarController.swift`

- [ ] **Step 1: Create `Hum/StatusBar/StatusBarController.swift`**

```swift
import AppKit
import Combine

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()
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

    private func observe() {
        musicObserver.$currentTrack
            .removeDuplicates()
            .sink { [weak self] track in
                guard let self else { return }
                Task { @MainActor in await self.handleTrackChange(track) }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(musicObserver.$isPlaying, lyricsState.$lines)
            .sink { [weak self] isPlaying, lines in
                guard let self else { return }
                if isPlaying && !lines.isEmpty {
                    self.windowManager.show()
                } else {
                    self.windowManager.hide()
                }
            }
            .store(in: &cancellables)
    }

    private func handleTrackChange(_ track: Track?) async {
        guard let track else { lyricsState.lines = []; return }
        lyricsState.lines = await lyricsEngine.fetch(for: track)
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add Hum/StatusBar/StatusBarController.swift
git commit -m "feat: add StatusBarController with Combine wiring and sync offset menu"
```

---

### Task 10: App Entry Point + Full Integration

**Files:**
- Modify: `Hum/HumApp.swift` (replace shell with final version)
- Create: `Hum/AppDelegate.swift`

- [ ] **Step 1: Create `Hum/AppDelegate.swift`**

```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private let musicObserver = MusicObserver()
    private let lyricsEngine = LyricsEngine()
    private let lyricsState = LyricsState()
    private var windowManager: WindowManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowManager = WindowManager(lyricsState: lyricsState, musicObserver: musicObserver)
        statusBarController = StatusBarController(
            musicObserver: musicObserver,
            lyricsEngine: lyricsEngine,
            lyricsState: lyricsState,
            windowManager: windowManager
        )
        musicObserver.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        musicObserver.stop()
    }
}
```

- [ ] **Step 2: Replace `Hum/HumApp.swift` with final version**

```swift
import SwiftUI

@main
struct HumApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
```

- [ ] **Step 3: Build the full app**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED` with no errors.

- [ ] **Step 4: Run all tests**

```bash
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(PASS|FAIL|error:|BUILD)"
```

Expected: All 17 tests PASS, `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add Hum/HumApp.swift Hum/AppDelegate.swift
git commit -m "feat: wire all components — Hum is fully integrated and ready to run"
```

---

## Manual Smoke Test Checklist

After Task 10 completes, run these manually before considering the app done:

- [ ] Open Xcode, run the Hum scheme — music note appears in menu bar, no dock icon
- [ ] Open Apple Music, play a track that has lyrics — floating window appears bottom-center
- [ ] Confirm lyrics scroll and highlight the active line as the track plays
- [ ] Pause the track — floating window disappears
- [ ] Resume — window reappears at the same position
- [ ] Drag the window to a new position, quit Hum, relaunch — window appears at saved position
- [ ] Play a track with no lyrics on LRCLIB — window stays hidden, no crash
- [ ] Use the sync offset stepper in the menu — lyrics shift forward/backward in time
- [ ] Quit via menu item — app exits cleanly
