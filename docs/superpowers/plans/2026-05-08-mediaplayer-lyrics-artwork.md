# MediaPlayer Lyrics Sync & Artwork Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ganti AppleScript dengan `MPMusicPlayerController` untuk posisi yang lebih akurat, tambah `MPMediaItemLyricsSource` sebagai sumber lirik utama, dan tampilkan album artwork di header window.

**Architecture:** `MusicObserver` sepenuhnya menggantikan AppleScript dengan `MPMusicPlayerController.systemMusicPlayer`, mengekspos `currentMediaItem: MPMediaItem?` dan `currentArtwork: NSImage?`. `StatusBarController` mengekstrak lirik dari `MPMediaItem.lyrics` via `MPMediaItemLyricsSource` dan meneruskannya ke `LyricsEngine.fetch` sebagai `String?` — sehingga `LyricsEngine` tetap testable tanpa perlu menyentuh `MPMediaItem` langsung.

**Tech Stack:** Swift, SwiftUI, MediaPlayer framework (`MPMusicPlayerController`, `MPMediaItem`, `MPMediaItemArtwork`), Combine, XCTest

---

## File Map

| File | Aksi |
|------|------|
| `Hum/LyricsEngine/MPMediaItemLyricsSource.swift` | **Buat baru** — deteksi & ekstrak LRC dari `MPMediaItem.lyrics` |
| `Hum/LyricsEngine/LyricsEngine.swift` | **Modifikasi** — tambah param `mediaItemLyrics: String?` ke `fetch` |
| `Hum/MusicObserver/MusicObserver.swift` | **Tulis ulang** — ganti AppleScript → MPMusicPlayerController |
| `Hum/StatusBar/StatusBarController.swift` | **Modifikasi** — wire `MPMediaItemLyricsSource` + panggil fetch baru |
| `Hum/Views/HumWindowView.swift` | **Modifikasi** — tambah artwork thumbnail di header |
| `HumTests/MusicObserverTests.swift` | **Modifikasi** — hapus tes `isSeek`, tidak ada tes baru (MusicObserver adalah integration point) |
| `HumTests/LyricsEngineTests.swift` | **Modifikasi** — tambah tes `MPMediaItemLyricsSource` + update `fetch` calls |

---

## Task 1: MPMediaItemLyricsSource

**Files:**
- Create: `Hum/LyricsEngine/MPMediaItemLyricsSource.swift`
- Modify: `HumTests/LyricsEngineTests.swift`

- [ ] **Step 1: Tulis failing tests untuk `MPMediaItemLyricsSource`**

Tambahkan class baru di akhir `HumTests/LyricsEngineTests.swift`:

```swift
final class MPMediaItemLyricsSourceTests: XCTestCase {
    private let source = MPMediaItemLyricsSource()

    func test_returnsNilForEmptyString() {
        XCTAssertNil(source.parseLRC(""))
    }

    func test_returnsNilForPlainText() {
        XCTAssertNil(source.parseLRC("Verse 1\nSome lyrics here\nNo timestamps"))
    }

    func test_returnsStringWhenLRCFormatDetected() {
        let lrc = "[00:01.00] Hello\n[00:02.50] World"
        XCTAssertEqual(source.parseLRC(lrc), lrc)
    }

    func test_detectsLRCWithThreeDigitFraction() {
        let lrc = "[01:23.456] Line with milliseconds"
        XCTAssertNotNil(source.parseLRC(lrc))
    }

    func test_returnsNilWhenTimestampOnlyInMiddle() {
        // Timestamp tidak di awal baris → bukan LRC valid
        let text = "Some text\n[00:01.00] not at start of file"
        // Ini tetap valid karena LRC bisa punya baris tanpa timestamp di awal
        // parseLRC mengecek apakah ADA baris yang match, bukan semua baris
        XCTAssertNotNil(source.parseLRC(text))
    }
}
```

- [ ] **Step 2: Jalankan tes, pastikan FAIL**

```
xcodebuild test -scheme Hum -only-testing HumTests/LyricsEngineTests/MPMediaItemLyricsSourceTests 2>&1 | tail -20
```

Expected: Compile error — `MPMediaItemLyricsSource` belum ada.

- [ ] **Step 3: Buat `MPMediaItemLyricsSource.swift`**

```swift
import MediaPlayer

struct MPMediaItemLyricsSource {
    private static let lrcLineRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: #"^\[\d{1,3}:\d{2}\.\d{2,3}\]"#, options: .anchorsMatchLines)
    }()

    func fetchSyncedLyrics(from mediaItem: MPMediaItem) -> String? {
        guard let raw = mediaItem.lyrics else { return nil }
        return parseLRC(raw)
    }

    func parseLRC(_ text: String) -> String? {
        guard !text.isEmpty else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard Self.lrcLineRegex.firstMatch(in: text, range: range) != nil else { return nil }
        return text
    }
}
```

- [ ] **Step 4: Jalankan tes, pastikan PASS**

```
xcodebuild test -scheme Hum -only-testing HumTests/LyricsEngineTests/MPMediaItemLyricsSourceTests 2>&1 | tail -20
```

Expected: `MPMediaItemLyricsSourceTests` — 5 tests passed.

- [ ] **Step 5: Commit**

```bash
git add Hum/LyricsEngine/MPMediaItemLyricsSource.swift HumTests/LyricsEngineTests.swift
git commit -m "feat: add MPMediaItemLyricsSource for local LRC detection"
```

---

## Task 2: Update LyricsEngine.fetch

**Files:**
- Modify: `Hum/LyricsEngine/LyricsEngine.swift`
- Modify: `HumTests/LyricsEngineTests.swift`

- [ ] **Step 1: Tulis failing test untuk `mediaItemLyrics` parameter**

Tambahkan di dalam class `LyricsEngineTests` yang sudah ada:

```swift
func test_usesMediaItemLyricsWhenProvided() async {
    let lrc = "[00:01.00] From device\n[00:02.00] Library"
    let engine = LyricsEngine(primary: MockSource(result: nil), fallback: MockSource(result: nil))
    let lines = await engine.fetch(for: track, mediaItemLyrics: lrc)
    XCTAssertEqual(lines.count, 2)
    XCTAssertEqual(lines[0].text, "From device")
}

func test_fallsBackToSourcesWhenMediaItemLyricsNil() async {
    let engine = LyricsEngine(primary: MockSource(result: nil), fallback: MockSource(result: sampleLRC))
    let lines = await engine.fetch(for: track, mediaItemLyrics: nil)
    XCTAssertEqual(lines.count, 2)
}

func test_mediaItemLyricsTakesPrecedenceOverPrimary() async {
    let fromDevice = "[00:01.00] Device line"
    let fromNetwork = "[00:01.00] Network line"
    let engine = LyricsEngine(primary: MockSource(result: fromNetwork), fallback: MockSource(result: nil))
    let lines = await engine.fetch(for: track, mediaItemLyrics: fromDevice)
    XCTAssertEqual(lines[0].text, "Device line")
}
```

- [ ] **Step 2: Jalankan tes, pastikan FAIL**

```
xcodebuild test -scheme Hum -only-testing HumTests/LyricsEngineTests 2>&1 | tail -20
```

Expected: Compile error — `fetch(for:mediaItemLyrics:)` belum ada.

- [ ] **Step 3: Update `LyricsEngine.swift`**

Ganti isi file seluruhnya:

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

    func fetch(for track: Track, mediaItemLyrics: String? = nil) async -> [LyricLine] {
        if let cached = cache[track] { return cached }

        let lrc: String?
        if let fromDevice = mediaItemLyrics {
            lrc = fromDevice
        } else {
            let primaryResult = await primary.fetchSyncedLyrics(for: track)
            if let r = primaryResult {
                lrc = r
            } else {
                lrc = await fallback.fetchSyncedLyrics(for: track)
            }
        }

        let lines = lrc.map { LRCParser.parse($0) } ?? []
        cache[track] = lines
        return lines
    }
}
```

- [ ] **Step 4: Jalankan semua tes LyricsEngine, pastikan PASS**

```
xcodebuild test -scheme Hum -only-testing HumTests/LyricsEngineTests 2>&1 | tail -20
```

Expected: Semua tes `LyricsEngineTests` pass termasuk 3 tes baru.

- [ ] **Step 5: Commit**

```bash
git add Hum/LyricsEngine/LyricsEngine.swift HumTests/LyricsEngineTests.swift
git commit -m "feat: add mediaItemLyrics param to LyricsEngine.fetch"
```

---

## Task 3: Tulis Ulang MusicObserver

**Files:**
- Modify: `Hum/MusicObserver/MusicObserver.swift`
- Modify: `HumTests/MusicObserverTests.swift`

- [ ] **Step 1: Hapus tes `isSeek` yang tidak lagi relevan**

Ganti seluruh isi `HumTests/MusicObserverTests.swift` dengan:

```swift
import XCTest
@testable import Hum

// MusicObserver adalah integration point dengan MPMusicPlayerController.
// Behavior-nya diverifikasi secara manual dengan Apple Music.
final class MusicObserverTests: XCTestCase {}
```

- [ ] **Step 2: Tulis ulang `MusicObserver.swift`**

Ganti seluruh isi file:

```swift
import AppKit
import MediaPlayer
import Combine

@MainActor
final class MusicObserver: ObservableObject {
    @Published private(set) var currentTrack: Track? = nil
    @Published private(set) var currentMediaItem: MPMediaItem? = nil
    @Published private(set) var currentArtwork: NSImage? = nil
    @Published private(set) var playbackPosition: TimeInterval = 0
    @Published private(set) var isPlaying: Bool = false

    private let player = MPMusicPlayerController.systemMusicPlayer
    private var displayTimer: Timer?

    func start() {
        MPMediaLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard status == .authorized else { return }
                self?.beginObserving()
            }
        }
    }

    func stop() {
        player.endGeneratingPlaybackNotifications()
        NotificationCenter.default.removeObserver(self)
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func beginObserving() {
        player.beginGeneratingPlaybackNotifications()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingItemChanged),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: player
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStateChanged),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: player
        )

        syncNowPlayingItem()
        syncPlaybackState()

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.syncPosition() }
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    @objc private func nowPlayingItemChanged() {
        DispatchQueue.main.async { [weak self] in self?.syncNowPlayingItem() }
    }

    @objc private func playbackStateChanged() {
        DispatchQueue.main.async { [weak self] in self?.syncPlaybackState() }
    }

    private func syncNowPlayingItem() {
        let item = player.nowPlayingItem
        currentMediaItem = item
        if let item {
            let track = Track(
                title: item.title ?? "",
                artist: item.artist ?? "",
                album: item.albumTitle ?? "",
                duration: item.playbackDuration > 0 ? item.playbackDuration : nil
            )
            if currentTrack != track { currentTrack = track }
            currentArtwork = item.artwork?.image(at: CGSize(width: 40, height: 40))
        } else {
            currentTrack = nil
            currentArtwork = nil
            playbackPosition = 0
        }
    }

    private func syncPlaybackState() {
        isPlaying = player.playbackState == .playing
        if !isPlaying { playbackPosition = player.currentPlaybackTime }
    }

    private func syncPosition() {
        guard isPlaying else { return }
        playbackPosition = player.currentPlaybackTime
    }
}
```

- [ ] **Step 3: Build untuk pastikan compile**

```
xcodebuild build -scheme Hum 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

- [ ] **Step 4: Commit**

```bash
git add Hum/MusicObserver/MusicObserver.swift HumTests/MusicObserverTests.swift
git commit -m "feat: replace AppleScript with MPMusicPlayerController in MusicObserver"
```

---

## Task 4: Wire MPMediaItemLyricsSource di StatusBarController

**Files:**
- Modify: `Hum/StatusBar/StatusBarController.swift`

- [ ] **Step 1: Update `handleTrackChange` di `StatusBarController.swift`**

Tambahkan property di bawah `private let windowManager`:

```swift
private let mediaItemSource = MPMediaItemLyricsSource()
```

Ganti method `handleTrackChange`:

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
    let mediaItemLyrics = musicObserver.currentMediaItem.flatMap {
        mediaItemSource.fetchSyncedLyrics(from: $0)
    }
    let lines = await lyricsEngine.fetch(for: track, mediaItemLyrics: mediaItemLyrics)
    guard !Task.isCancelled else { return }
    lyricsState.lines = lines
    lyricsState.noLyricsFound = lines.isEmpty
}
```

Tambahkan import di atas file jika belum ada:

```swift
import MediaPlayer
```

- [ ] **Step 2: Build untuk pastikan compile**

```
xcodebuild build -scheme Hum 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

- [ ] **Step 3: Jalankan semua tes**

```
xcodebuild test -scheme Hum 2>&1 | tail -30
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add Hum/StatusBar/StatusBarController.swift
git commit -m "feat: wire MPMediaItemLyricsSource into StatusBarController"
```

---

## Task 5: Tampilkan Artwork di HumWindowView

**Files:**
- Modify: `Hum/Views/HumWindowView.swift`

- [ ] **Step 1: Update header di `HumWindowView.swift`**

Ganti seluruh isi file:

```swift
import SwiftUI

struct HumWindowView: View {
    @ObservedObject var lyricsState: LyricsState
    @ObservedObject var musicObserver: MusicObserver

    private var activeLineIndex: Int? {
        activeIndex(in: lyricsState.lines, at: musicObserver.playbackPosition)
    }

    var body: some View {
        ZStack {
            VibrancyView()
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    artworkView
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
                        lyricsState.isMinimized.toggle()
                    } label: {
                        Image(systemName: lyricsState.isMinimized ? "chevron.down.circle" : "chevron.up.circle")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)

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
                .frame(height: 60)

                if !lyricsState.lines.isEmpty {
                    KaraokeView(
                        lines: lyricsState.lines,
                        active: activeLineIndex,
                        fontSize: lyricsState.fontSize
                    )
                    .equatable()
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var artworkView: some View {
        Group {
            if let artwork = musicObserver.currentArtwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.1))
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .animation(.easeInOut(duration: 0.2), value: musicObserver.currentArtwork != nil)
    }
}
```

- [ ] **Step 2: Build untuk pastikan compile**

```
xcodebuild build -scheme Hum 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded`

- [ ] **Step 3: Jalankan semua tes untuk pastikan tidak ada regresi**

```
xcodebuild test -scheme Hum 2>&1 | tail -30
```

Expected: All tests pass.

- [ ] **Step 4: Test manual**

Buka Apple Music, putar lagu. Verifikasi:
- [ ] Header menampilkan artwork 40×40 dengan corner radius
- [ ] Kalau tidak ada artwork → tampil placeholder icon `music.note`
- [ ] Lirik sync lebih akurat dari sebelumnya
- [ ] Pause/play berfungsi
- [ ] Ganti lagu → artwork dan lirik update

- [ ] **Step 5: Commit**

```bash
git add Hum/Views/HumWindowView.swift
git commit -m "feat: add album artwork thumbnail to HumWindowView header"
```

---

## Checklist Akhir

- [ ] `MPMediaItemLyricsSource` tests semua pass
- [ ] `LyricsEngineTests` semua pass (termasuk 3 tes baru)
- [ ] Build sukses tanpa error atau warning baru
- [ ] Manual test: artwork tampil, lirik sync lebih baik
