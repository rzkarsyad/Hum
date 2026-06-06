# Browser Media Detection (YouTube / YT Music) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show synced lyrics for music played in a browser (YouTube Music / music videos) by reading macOS system Now Playing via the MediaRemote adapter, as an additional browser-only source alongside Apple Music and Spotify.

**Architecture:** A new `BrowserMediaSource` owns an `/usr/bin/perl` subprocess running the BSD-3 `ungive/mediaremote-adapter`, which streams now-playing JSON. Pure functions parse each line and filter to browser bundle IDs. `MusicObserver` merges this browser snapshot with its existing AppleScript poll (priority Apple Music ▸ Spotify ▸ Browser) and publishes a unified now-playing state. For browser sources the lyrics window only appears when synced lyrics are actually found.

**Tech Stack:** Swift 5.9, AppKit + SwiftUI, Combine, Foundation.Process, xcodegen, XCTest. macOS 15+ deployment, built on macOS 26 SDK.

**Spec:** `docs/superpowers/specs/2026-06-07-browser-media-detection-design.md`

**Base branch:** `feat/browser-media-detection` (off `main`, which already contains the Spotify multi-source foundation: `PlayerSource`, `parsePollResult`, source-aware artwork).

---

## File Structure

- **Create** `Hum/MusicObserver/BrowserMediaSource.swift` — `BrowserSnapshot`, `BrowserParse`, `isBrowserBundleID`, `parseBrowserNowPlaying` (pure, top-level), and the `BrowserMediaSource` class (subprocess owner).
- **Create** `HumTests/BrowserMediaSourceTests.swift` — unit tests for the pure functions.
- **Create** `Vendor/MediaRemoteAdapter/` — vendored adapter files (`mediaremote-adapter.pl`, `MediaRemoteAdapter.framework`, `LICENSE`).
- **Modify** `Hum/MusicObserver/MusicObserver.swift` — add `.browser` to `PlayerSource`; add `mergeOutcome`; hold + start/stop a `BrowserMediaSource`; merge in `applyPollResult`; publish `currentSource`; browser artwork.
- **Modify** `HumTests/MusicObserverTests.swift` — `mergeOutcome` tests.
- **Modify** `Hum/StatusBar/StatusBarController.swift` — source-aware `hasContent`.
- **Modify** `project.yml` — bundle `Vendor/MediaRemoteAdapter` as a folder resource.
- **Modify** `README.md`, `CHANGELOG.md` — document the feature.

---

## Task 1: Pure types + browser bundle-ID allowlist

**Files:**
- Create: `Hum/MusicObserver/BrowserMediaSource.swift`
- Test: `HumTests/BrowserMediaSourceTests.swift`

- [ ] **Step 1: Write the failing test**

Create `HumTests/BrowserMediaSourceTests.swift`:

```swift
import XCTest
@testable import Hum

final class BrowserMediaSourceTests: XCTestCase {

    func test_isBrowserBundleID_knownBrowsers() {
        XCTAssertTrue(isBrowserBundleID("com.google.Chrome"))
        XCTAssertTrue(isBrowserBundleID("com.apple.Safari"))
        XCTAssertTrue(isBrowserBundleID("company.thebrowser.Browser"))
        XCTAssertTrue(isBrowserBundleID("com.brave.Browser"))
        XCTAssertTrue(isBrowserBundleID("com.microsoft.edgemac"))
    }

    func test_isBrowserBundleID_nonBrowsers() {
        XCTAssertFalse(isBrowserBundleID("com.apple.Music"))
        XCTAssertFalse(isBrowserBundleID("com.spotify.client"))
        XCTAssertFalse(isBrowserBundleID(""))
        XCTAssertFalse(isBrowserBundleID("com.example.random"))
    }
}
```

- [ ] **Step 2: Create the source file with the types and allowlist**

Create `Hum/MusicObserver/BrowserMediaSource.swift`:

```swift
import Foundation

/// A now-playing snapshot for media playing in a browser, derived from the
/// MediaRemote adapter stream. Times are in seconds.
struct BrowserSnapshot: Equatable {
    let bundleID: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval?
    let isPlaying: Bool
    let elapsedTime: TimeInterval
    let playbackRate: Double
    let artworkData: Data?
}

/// Outcome of parsing one now-playing JSON line.
enum BrowserParse: Equatable {
    case browser(BrowserSnapshot)  // a browser is the now-playing app (may be paused)
    case other                     // valid now-playing info, but not a browser
    case ignore                    // unparseable / no usable info — keep previous state
}

/// Bundle identifiers of browsers whose media we surface. Chromium variants and
/// Safari report MediaSession metadata to macOS Now Playing; Firefox is included
/// best-effort.
func isBrowserBundleID(_ id: String) -> Bool {
    let browsers: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.dev", "com.google.Chrome.canary",
        "com.apple.Safari", "com.apple.SafariTechnologyPreview",
        "company.thebrowser.Browser",            // Arc
        "com.brave.Browser", "com.brave.Browser.beta", "com.brave.Browser.nightly",
        "com.microsoft.edgemac", "com.microsoft.edgemac.beta",
        "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition",
        "com.operasoftware.Opera", "com.operasoftware.OperaGX",
        "com.vivaldi.Vivaldi",
        "ru.yandex.desktop.yandex-browser",
    ]
    return browsers.contains(id)
}
```

- [ ] **Step 3: Register the new files in the Xcode project**

Run: `xcodegen generate`
Expected: `Loaded project ... Created project at Hum.xcodeproj`

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/BrowserMediaSourceTests 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`, both `isBrowserBundleID` tests pass.

- [ ] **Step 5: Commit**

```bash
git add Hum/MusicObserver/BrowserMediaSource.swift HumTests/BrowserMediaSourceTests.swift Hum.xcodeproj
git commit -m "feat: browser bundle-ID allowlist + now-playing snapshot types"
```

---

## Task 2: Parse one now-playing JSON line

**Files:**
- Modify: `Hum/MusicObserver/BrowserMediaSource.swift`
- Test: `HumTests/BrowserMediaSourceTests.swift`

- [ ] **Step 1: Write the failing tests**

Add to `BrowserMediaSourceTests.swift` (inside the class):

```swift
func test_parse_browserPlaying() {
    let line = #"{"bundleIdentifier":"com.google.Chrome","playing":true,"title":"Blinding Lights","artist":"The Weeknd","album":"After Hours","duration":200.0,"elapsedTime":42.5,"playbackRate":1.0}"#
    guard case let .browser(s) = parseBrowserNowPlaying(line) else { return XCTFail("expected .browser") }
    XCTAssertEqual(s.bundleID, "com.google.Chrome")
    XCTAssertEqual(s.title, "Blinding Lights")
    XCTAssertEqual(s.artist, "The Weeknd")
    XCTAssertEqual(s.album, "After Hours")
    XCTAssertEqual(s.duration ?? 0, 200.0, accuracy: 0.001)
    XCTAssertEqual(s.elapsedTime, 42.5, accuracy: 0.001)
    XCTAssertTrue(s.isPlaying)
}

func test_parse_browserPaused() {
    let line = #"{"bundleIdentifier":"com.apple.Safari","playing":false,"title":"Some Song"}"#
    guard case let .browser(s) = parseBrowserNowPlaying(line) else { return XCTFail("expected .browser") }
    XCTAssertFalse(s.isPlaying)
    XCTAssertEqual(s.artist, "")   // missing optional → empty
    XCTAssertNil(s.duration)
}

func test_parse_nonBrowserIsOther() {
    let line = #"{"bundleIdentifier":"com.apple.Music","playing":true,"title":"X"}"#
    XCTAssertEqual(parseBrowserNowPlaying(line), .other)
}

func test_parse_matchesViaParentBundleID() {
    let line = #"{"bundleIdentifier":"com.google.Chrome.helper","parentApplicationBundleIdentifier":"com.google.Chrome","playing":true,"title":"Y"}"#
    guard case let .browser(s) = parseBrowserNowPlaying(line) else { return XCTFail("expected .browser") }
    XCTAssertEqual(s.bundleID, "com.google.Chrome")
}

func test_parse_artworkBase64Decoded() {
    // base64 of "hi" = "aGk="
    let line = #"{"bundleIdentifier":"com.google.Chrome","playing":true,"title":"T","artworkData":"aGk="}"#
    guard case let .browser(s) = parseBrowserNowPlaying(line) else { return XCTFail("expected .browser") }
    XCTAssertEqual(s.artworkData, Data("hi".utf8))
}

func test_parse_malformedIsIgnore() {
    XCTAssertEqual(parseBrowserNowPlaying("not json"), .ignore)
    XCTAssertEqual(parseBrowserNowPlaying(""), .ignore)
}

func test_parse_browserWithoutTitleIsOther() {
    let line = #"{"bundleIdentifier":"com.google.Chrome","playing":true}"#
    XCTAssertEqual(parseBrowserNowPlaying(line), .other)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/BrowserMediaSourceTests 2>&1 | tail -15`
Expected: compile failure — `cannot find 'parseBrowserNowPlaying' in scope`.

- [ ] **Step 3: Implement `parseBrowserNowPlaying`**

Add to `BrowserMediaSource.swift` (top-level, after `isBrowserBundleID`):

```swift
/// Parse one NDJSON line from the adapter stream.
func parseBrowserNowPlaying(_ jsonLine: String) -> BrowserParse {
    guard let data = jsonLine.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return .ignore }

    let bundleID = (obj["bundleIdentifier"] as? String) ?? ""
    let parentID = (obj["parentApplicationBundleIdentifier"] as? String) ?? ""
    let isBrowser = isBrowserBundleID(bundleID) || isBrowserBundleID(parentID)
    guard isBrowser else { return .other }

    guard let title = obj["title"] as? String, !title.isEmpty else { return .other }
    let effectiveID = isBrowserBundleID(bundleID) ? bundleID : parentID

    var artwork: Data?
    if let b64 = obj["artworkData"] as? String { artwork = Data(base64Encoded: b64) }

    return .browser(BrowserSnapshot(
        bundleID: effectiveID,
        title: title,
        artist: (obj["artist"] as? String) ?? "",
        album: (obj["album"] as? String) ?? "",
        duration: obj["duration"] as? Double,
        isPlaying: (obj["playing"] as? Bool) ?? false,
        elapsedTime: (obj["elapsedTime"] as? Double) ?? 0,
        playbackRate: (obj["playbackRate"] as? Double) ?? 1.0,
        artworkData: artwork
    ))
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/BrowserMediaSourceTests 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`, all parse tests pass.

- [ ] **Step 5: Commit**

```bash
git add Hum/MusicObserver/BrowserMediaSource.swift HumTests/BrowserMediaSourceTests.swift
git commit -m "feat: parse MediaRemote now-playing JSON into browser snapshot"
```

---

## Task 3: Merge logic + `.browser` source

**Files:**
- Modify: `Hum/MusicObserver/MusicObserver.swift:10-13` (add `.browser`), add `mergeOutcome` near `parsePollResult`
- Test: `HumTests/MusicObserverTests.swift`

- [ ] **Step 1: Write the failing tests**

Add to `HumTests/MusicObserverTests.swift` (inside the class):

```swift
// MARK: - mergeOutcome

private func snap(playing: Bool, title: String = "Song") -> BrowserSnapshot {
    BrowserSnapshot(bundleID: "com.google.Chrome", title: title, artist: "A", album: "Al",
                    duration: 180, isPlaying: playing, elapsedTime: 10, playbackRate: 1, artworkData: nil)
}

func test_merge_appleScriptPlayingWins() {
    let asPlaying = PollOutcome.playing(PollResult(source: .spotify,
        track: Track(title: "S", artist: "B", album: "C"), position: 5))
    let result = mergeOutcome(appleScript: asPlaying, browser: snap(playing: true), browserPosition: 99)
    XCTAssertEqual(result, asPlaying)   // AppleScript source keeps priority
}

func test_merge_browserWinsWhenAppleScriptStopped() {
    let result = mergeOutcome(appleScript: .stopped, browser: snap(playing: true), browserPosition: 33)
    guard case let .playing(p) = result else { return XCTFail("expected .playing") }
    XCTAssertEqual(p.source, .browser)
    XCTAssertEqual(p.track.title, "Song")
    XCTAssertEqual(p.position, 33, accuracy: 0.001)
}

func test_merge_pausedBrowserDoesNotWin() {
    let result = mergeOutcome(appleScript: .stopped, browser: snap(playing: false), browserPosition: 1)
    XCTAssertEqual(result, .stopped)
}

func test_merge_noBrowserFallsBackToAppleScript() {
    XCTAssertEqual(mergeOutcome(appleScript: .paused, browser: nil, browserPosition: 0), .paused)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/MusicObserverTests 2>&1 | tail -15`
Expected: compile failure — `cannot find 'mergeOutcome'` and `type 'PlayerSource' has no member 'browser'`.

- [ ] **Step 3: Add `.browser` to `PlayerSource`**

In `Hum/MusicObserver/MusicObserver.swift`, change the enum (lines 10-13):

```swift
enum PlayerSource: String, Equatable {
    case appleMusic = "music"
    case spotify = "spotify"
    case browser = "browser"
}
```

- [ ] **Step 4: Add `mergeOutcome`**

In `Hum/MusicObserver/MusicObserver.swift`, add directly after `parsePollResult` (after line 44):

```swift
/// Combine the AppleScript outcome (Apple Music / Spotify) with the latest
/// browser snapshot. Priority: a *playing* Apple Music / Spotify always wins;
/// otherwise a *playing* browser wins; otherwise reflect the AppleScript state.
func mergeOutcome(appleScript: PollOutcome, browser: BrowserSnapshot?, browserPosition: TimeInterval) -> PollOutcome {
    if case .playing = appleScript { return appleScript }
    if let b = browser, b.isPlaying {
        let track = Track(title: b.title, artist: b.artist, album: b.album, duration: b.duration)
        return .playing(PollResult(source: .browser, track: track, position: browserPosition))
    }
    return appleScript
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/MusicObserverTests 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`. (The existing `fetchArtworkSync(source:)` switch now misses `.browser` — if the build errors with "switch must be exhaustive", that is fixed in Task 6; for now add a temporary `case .browser: return nil` if needed to compile. Task 6 replaces it.)

> Note: adding `.browser` makes the `switch source` in `fetchArtworkSync` non-exhaustive. To keep this task green, add `case .browser: return nil` to that switch now; Task 6 implements it properly.

- [ ] **Step 6: Commit**

```bash
git add Hum/MusicObserver/MusicObserver.swift HumTests/MusicObserverTests.swift
git commit -m "feat: source-merge logic with browser priority"
```

---

## Task 4: Vendor the MediaRemote adapter + bundle it

**Files:**
- Create: `Vendor/MediaRemoteAdapter/{mediaremote-adapter.pl, MediaRemoteAdapter.framework, LICENSE}`
- Modify: `project.yml`

- [ ] **Step 1: Download the adapter release**

Run:
```bash
mkdir -p Vendor/MediaRemoteAdapter
gh release download --repo ungive/mediaremote-adapter --dir /tmp/mra --clobber
ls -la /tmp/mra
```
Expected: release assets listed. The release contains `mediaremote-adapter.pl` and `MediaRemoteAdapter.framework` (possibly inside a `.zip`/`.tar.gz` — unzip/untar if so). **Confirm the asset names** from `ls`; if packaged in an archive, extract it first (`unzip /tmp/mra/<asset>.zip -d /tmp/mra`).

- [ ] **Step 2: Copy the required files into the repo**

Run:
```bash
cp /tmp/mra/mediaremote-adapter.pl Vendor/MediaRemoteAdapter/
cp -R /tmp/mra/MediaRemoteAdapter.framework Vendor/MediaRemoteAdapter/
cp /tmp/mra/LICENSE Vendor/MediaRemoteAdapter/ 2>/dev/null || curl -fsSL https://raw.githubusercontent.com/ungive/mediaremote-adapter/main/LICENSE -o Vendor/MediaRemoteAdapter/LICENSE
```

- [ ] **Step 3: Verify the framework is a universal binary**

Run:
```bash
lipo -archs Vendor/MediaRemoteAdapter/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter 2>/dev/null \
  || lipo -archs Vendor/MediaRemoteAdapter/MediaRemoteAdapter.framework/MediaRemoteAdapter
```
Expected: `x86_64 arm64` (both). If only one arch, the feature still runs on this Mac but note it in the commit.

- [ ] **Step 4: Bundle the folder via xcodegen**

In `project.yml`, change the `Hum` target's `sources:` from:

```yaml
    sources:
      - Hum
```

to:

```yaml
    sources:
      - Hum
      - path: Vendor/MediaRemoteAdapter
        type: folder
        buildPhase: resources
```

(`type: folder` adds a folder reference copied verbatim into `Hum.app/Contents/Resources/MediaRemoteAdapter/`.)

- [ ] **Step 5: Regenerate and build**

Run:
```bash
xcodegen generate
xcodebuild build -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Confirm the resource landed in the built app**

Run:
```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData -type d -name "Hum.app" -path "*Debug*" 2>/dev/null | head -1)
ls "$APP/Contents/Resources/MediaRemoteAdapter/"
```
Expected: lists `mediaremote-adapter.pl`, `MediaRemoteAdapter.framework`, `LICENSE`.

- [ ] **Step 7: Commit**

```bash
git add Vendor/MediaRemoteAdapter project.yml Hum.xcodeproj
git commit -m "build: vendor ungive/mediaremote-adapter and bundle into app resources"
```

---

## Task 5: `BrowserMediaSource` subprocess owner

**Files:**
- Modify: `Hum/MusicObserver/BrowserMediaSource.swift` (append the class)

No unit test — this is subprocess/IO integration, verified by build + manual run.

- [ ] **Step 1: Append the `BrowserMediaSource` class**

Add to the end of `Hum/MusicObserver/BrowserMediaSource.swift`:

```swift
/// Owns the `/usr/bin/perl` MediaRemote adapter subprocess and exposes the latest
/// browser now-playing snapshot. Thread-safe; safe to call `current(now:)` from
/// the main actor. Degrades silently if the adapter is unavailable.
final class BrowserMediaSource {
    private let lock = NSLock()
    private var snapshot: BrowserSnapshot?
    private var receivedAt = Date()

    private var process: Process?
    private var buffer = Data()
    private var failureCount = 0
    private var isStopped = false
    private let maxFailures = 5

    func start() {
        isStopped = false
        guard adapterAvailable() else {
            NSLog("[Hum] MediaRemote adapter unavailable — browser detection disabled.")
            return
        }
        launchStream()
    }

    func stop() {
        isStopped = true
        process?.terminate()
        process = nil
    }

    /// Latest playing browser snapshot with a live-extrapolated position, or nil.
    func current(now: Date) -> (snapshot: BrowserSnapshot, position: TimeInterval)? {
        lock.lock(); defer { lock.unlock() }
        guard let s = snapshot, s.isPlaying else { return nil }
        let rate = s.playbackRate == 0 ? 1.0 : s.playbackRate
        let pos = max(0, s.elapsedTime + now.timeIntervalSince(receivedAt) * rate)
        return (s, pos)
    }

    // MARK: - Paths

    private static func adapterDir() -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent("MediaRemoteAdapter", isDirectory: true)
    }

    private func adapterAvailable() -> Bool {
        guard let dir = Self.adapterDir() else { return false }
        let fm = FileManager.default
        return fm.fileExists(atPath: dir.appendingPathComponent("mediaremote-adapter.pl").path)
            && fm.fileExists(atPath: dir.appendingPathComponent("MediaRemoteAdapter.framework").path)
            && fm.fileExists(atPath: "/usr/bin/perl")
    }

    // MARK: - Stream

    private func launchStream() {
        guard let dir = Self.adapterDir() else { return }
        let script = dir.appendingPathComponent("mediaremote-adapter.pl").path
        let framework = dir.appendingPathComponent("MediaRemoteAdapter.framework").path

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        proc.arguments = [script, framework, "stream"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            self?.ingest(chunk)
        }

        proc.terminationHandler = { [weak self] _ in
            guard let self, !self.isStopped else { return }
            self.failureCount += 1
            guard self.failureCount <= self.maxFailures else {
                NSLog("[Hum] MediaRemote adapter failed repeatedly — browser detection disabled.")
                return
            }
            let delay = min(pow(2.0, Double(self.failureCount)), 30)
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, !self.isStopped else { return }
                self.launchStream()
            }
        }

        do {
            try proc.run()
            lock.lock(); process = proc; lock.unlock()
        } catch {
            NSLog("[Hum] Failed to launch MediaRemote adapter: \(error)")
        }
    }

    private func ingest(_ chunk: Data) {
        var completeLines: [String] = []
        lock.lock()
        buffer.append(chunk)
        while let nl = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer.subdata(in: buffer.startIndex..<nl)
            buffer.removeSubrange(buffer.startIndex...nl)
            if let str = String(data: lineData, encoding: .utf8) { completeLines.append(str) }
        }
        lock.unlock()

        for line in completeLines {
            switch parseBrowserNowPlaying(line) {
            case .browser(let s):
                lock.lock(); snapshot = s; receivedAt = Date(); lock.unlock()
            case .other:
                lock.lock(); snapshot = nil; lock.unlock()
            case .ignore:
                break  // keep previous state
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Hum/MusicObserver/BrowserMediaSource.swift
git commit -m "feat: BrowserMediaSource subprocess owner for MediaRemote stream"
```

---

## Task 6: Wire the browser source into `MusicObserver`

**Files:**
- Modify: `Hum/MusicObserver/MusicObserver.swift`

- [ ] **Step 1: Publish `currentSource` and hold the browser source**

Replace the property block **lines 53–61** (from `private var pollTimer` through `private var artworkGeneration = 0`) with the following — this keeps all existing properties, makes `currentSource` published, and adds `lastBrowserArtwork`, `browserSource`, and an `init`:

```swift
    private var pollTimer: Timer?
    private var displayTimer: Timer?
    private var basePosition: TimeInterval = 0
    private var baseDate: Date = Date()
    @Published private(set) var currentSource: PlayerSource = .appleMusic
    private var lastBrowserArtwork: Data?

    private let pollQueue = DispatchQueue(label: "com.hum.poll", qos: .userInteractive)
    private let artworkQueue = DispatchQueue(label: "com.hum.artwork", qos: .utility)
    private var artworkGeneration = 0
    private let browserSource: BrowserMediaSource

    init(browserSource: BrowserMediaSource = BrowserMediaSource()) {
        self.browserSource = browserSource
    }
```

(`MusicObserver()` in `AppDelegate` still compiles via the default argument — no change needed there.)

- [ ] **Step 2: Start/stop the browser source**

In `start()` (after the display timer block, before the closing brace at line 75), add:

```swift
        browserSource.start()
```

In `stop()` (line 77-80), add `browserSource.stop()`:

```swift
    func stop() {
        pollTimer?.invalidate(); pollTimer = nil
        displayTimer?.invalidate(); displayTimer = nil
        browserSource.stop()
    }
```

- [ ] **Step 3: Merge the browser snapshot in `applyPollResult`**

Replace the whole `applyPollResult` method (lines 96-121) with:

```swift
    private func applyPollResult(_ result: String, prePollDate: Date, basePos: TimeInterval, baseD: Date) {
        let browser = browserSource.current(now: prePollDate)
        let outcome = mergeOutcome(
            appleScript: parsePollResult(result),
            browser: browser?.snapshot,
            browserPosition: browser?.position ?? 0
        )
        switch outcome {
        case .playing(let poll):
            let trackChanged = (currentTrack != poll.track)
            if currentSource != poll.source { currentSource = poll.source }
            if trackChanged { currentTrack = poll.track }

            if poll.source == .browser {
                let art = browser?.snapshot.artworkData
                if trackChanged || art != lastBrowserArtwork {
                    lastBrowserArtwork = art
                    fetchArtwork(browserData: art)
                }
            } else if trackChanged {
                lastBrowserArtwork = nil
                fetchArtwork(browserData: nil)
            }

            let interpolated = basePos + prePollDate.timeIntervalSince(baseD)
            if isSeek(reported: poll.position, interpolated: interpolated) {
                playbackPosition = poll.position
            }
            basePosition = poll.position
            baseDate = prePollDate
            isPlaying = true
        case .paused:
            isPlaying = false
        case .stopped:
            isPlaying = false
            currentTrack = nil
            currentArtwork = nil
            playbackPosition = 0
            basePosition = 0
            baseDate = prePollDate
            lastBrowserArtwork = nil
        }
    }
```

- [ ] **Step 4: Pass browser artwork through `fetchArtwork`**

Replace `fetchArtwork()` (lines 191-202) with:

```swift
    private func fetchArtwork(browserData: Data?) {
        artworkGeneration += 1
        let gen = artworkGeneration
        let source = currentSource
        artworkQueue.async { [weak self] in
            let image = Self.fetchArtworkSync(source: source, browserData: browserData)
            Task { @MainActor [weak self] in
                guard let self, self.artworkGeneration == gen else { return }
                self.currentArtwork = image
            }
        }
    }
```

- [ ] **Step 5: Implement the `.browser` artwork case**

Replace `fetchArtworkSync(source:)` (lines 247-265) with the `browserData` variant and the new case (also removes the temporary `case .browser: return nil` from Task 3):

```swift
    private nonisolated static func fetchArtworkSync(source: PlayerSource, browserData: Data?) -> NSImage? {
        switch source {
        case .appleMusic:
            var err: NSDictionary?
            let desc = compiledMusicArtworkScript?.executeAndReturnError(&err)
            guard err == nil, let data = desc?.data, !data.isEmpty else { return nil }
            return NSImage(data: data)
        case .spotify:
            var err: NSDictionary?
            let desc = compiledSpotifyArtworkURLScript?.executeAndReturnError(&err)
            guard err == nil,
                  let urlString = desc?.stringValue,
                  let url = URL(string: urlString),
                  let data = try? Data(contentsOf: url),
                  !data.isEmpty
            else { return nil }
            return NSImage(data: data)
        case .browser:
            guard let data = browserData, !data.isEmpty else { return nil }
            return NSImage(data: data)
        }
    }
```

- [ ] **Step 6: Build and run the full unit suite**

Run:
```bash
xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "error:|Executed|BUILD FAILED|TEST SUCCEEDED"
```
Expected: `** TEST SUCCEEDED **`, all tests pass (Spotify, browser parse, merge, isSeek).

- [ ] **Step 7: Commit**

```bash
git add Hum/MusicObserver/MusicObserver.swift
git commit -m "feat: merge browser source into MusicObserver with browser artwork"
```

---

## Task 7: Window only appears when lyrics found (browser)

**Files:**
- Modify: `Hum/StatusBar/StatusBarController.swift:122-125`

- [ ] **Step 1: Make `hasContent` source-aware**

In `observe()`, replace the `hasContentPublisher` definition (lines 122-125) with:

```swift
        let hasContentPublisher = Publishers.CombineLatest4(
            lyricsState.$lines,
            lyricsState.$noLyricsFound,
            lyricsState.$networkError,
            musicObserver.$currentSource
        )
        .map { lines, noLyricsFound, networkError, source -> Bool in
            // For browser media, only show when synced lyrics actually exist —
            // stay hidden for ordinary videos / podcasts / no-lyrics tracks.
            if source == .browser { return !lines.isEmpty }
            return !lines.isEmpty || noLyricsFound || networkError
        }
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Hum/StatusBar/StatusBarController.swift
git commit -m "feat: suppress lyrics window for non-music browser media"
```

---

## Task 8: Manual verification + docs

**Files:**
- Modify: `README.md`, `CHANGELOG.md`

- [ ] **Step 1: Manual smoke test (run the app from Xcode or the built product)**

Verify each:
- Play a song on **YouTube Music** in a supported browser → grant any permission prompt → floating window appears with synced lyrics + artwork.
- Play an **ordinary YouTube video / podcast** → window stays hidden (no "No lyrics found").
- Play in **Apple Music** and **Spotify** → still work; when a desktop app and a browser both play, the desktop app wins.
- **Pause** the browser tab → window hides.
- Quit the app → no lingering `perl` process (`pgrep -fl mediaremote-adapter` returns nothing).

- [ ] **Step 2: Update README**

In `README.md`, change the Features list and Requirements to mention browser support. Replace the line:

```markdown
- **Works with Apple Music & Spotify** — detects whichever app is playing automatically
```

with:

```markdown
- **Works with Apple Music, Spotify & browsers** — detects whichever is playing; browser support (YouTube Music / music videos) via the system Now Playing bridge
```

And under Requirements, replace `- Apple Music or Spotify` with:

```markdown
- Apple Music, Spotify, or a supported browser (Chrome, Safari, Arc, Brave, Edge, Firefox)
```

- [ ] **Step 3: Update CHANGELOG**

In `CHANGELOG.md`, under `## [Unreleased]` → `### Added`, append:

```markdown
- **Browser media support** — Hum now shows synced lyrics for music played in a browser (YouTube Music and music videos), via the macOS Now Playing system (bundled `ungive/mediaremote-adapter`, BSD-3). The window stays hidden for non-music browser media. Apple Music / Spotify keep priority.
```

- [ ] **Step 4: Commit**

```bash
git add README.md CHANGELOG.md
git commit -m "docs: document browser media detection"
```

- [ ] **Step 5: Push and open PR**

```bash
git push -u origin feat/browser-media-detection
gh pr create --base main --head feat/browser-media-detection \
  --title "feat: browser media detection (YouTube / YouTube Music)" \
  --body "Implements the design in docs/superpowers/specs/2026-06-07-browser-media-detection-design.md. Adds a browser-only Now Playing source via the bundled MediaRemote adapter; Apple Music / Spotify unchanged. Window only appears when lyrics are found for browser media."
```

---

## Notes for the implementer

- **`/usr/bin/perl` entitlement** is what makes this work on macOS 15.4+/26 where direct MediaRemote is blocked. If `test`/`stream` produces no output, confirm perl exists and the framework path is correct; the feature degrades silently and Apple Music / Spotify are unaffected.
- **`timestamp` field is intentionally not used** — position is extrapolated from `elapsedTime` + wall-clock since the snapshot was received, which is robust regardless of the adapter's timestamp semantics.
- **Artwork may arrive a beat after the title** (documented upstream); the `lastBrowserArtwork` check refreshes it when it appears for the same track.
- **Adapter asset names** in Task 4 must be confirmed from the upstream releases page; everything else is exact.
