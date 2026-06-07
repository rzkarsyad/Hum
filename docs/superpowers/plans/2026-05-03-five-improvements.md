# Hum — Five Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Five improvements — text always visible during transition, full line duration, larger font, no-lyrics fallback with retry and message, and a menu toggle for auto-show behavior.

**Architecture:** Three sequential tasks — (1) KaraokeView fixes (base layer always dim, full duration, .title2 font); (2) no-lyrics handling (LRCLIBSource retry without album, LyricsState.noLyricsFound, HumWindowView message, StatusBarController visibility); (3) auto-show menu toggle (UserDefaults preference, conditional isManuallyHidden reset).

**Tech Stack:** SwiftUI, Combine, AppKit, UserDefaults

---

## File Map

| Path | Change |
|------|--------|
| `Hum/Views/KaraokeView.swift` | Base always 0.3; `lineDuration` = full available time; `.title2.bold()` |
| `Hum/LyricsEngine/LRCLIBSource.swift` | Retry without album name as fallback |
| `Hum/LyricsEngine/LyricsState.swift` | Add `@Published var noLyricsFound: Bool = false` |
| `Hum/Views/HumWindowView.swift` | Show "no lyrics" message when `noLyricsFound` |
| `Hum/StatusBar/StatusBarController.swift` | `hasContentPublisher`, `handleTrackChange` resets, "Auto-show on New Track" menu item |

---

### Task 1: KaraokeView — base always visible, full duration, bigger font

**Files:**
- Modify: `Hum/Views/KaraokeView.swift`

- [ ] **Step 1: Replace `Hum/Views/KaraokeView.swift`**

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

    private func lineDuration(for index: Int) -> TimeInterval {
        guard index + 1 < lines.count else { return 0.9 }
        let available = lines[index + 1].timestamp - lines[index].timestamp
        return max(available, 0.3)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        ZStack(alignment: .leading) {
                            // Base — always at 0.3, never hidden; text is always visible
                            Text(line.text)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .opacity(0.3)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if index == active {
                                Text(line.text)
                                    .customAttribute(EmphasisAttribute())
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .transition(.asymmetric(
                                        insertion: AnyTransition(TextTransition(duration: lineDuration(for: index))),
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

Three changes from current:
1. Base layer: `.opacity(0.3)` always — removed `.opacity(index == active ? 0.0 : 0.3)` and its `.animation` → text never disappears
2. `lineDuration`: `max(available, 0.3)` — removed the 0.85 multiplier and 1.5s cap → full line duration
3. Font: `.title2.bold()` on both Text views (was `.title3.bold()`)

- [ ] **Step 2: Build + run tests**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(Test Suite.*passed|FAIL|error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`, all 18 tests PASS.

- [ ] **Step 3: Commit**

```bash
git add Hum/Views/KaraokeView.swift
git commit -m "feat: base layer always visible, full line duration, title2 font"
```

---

### Task 2: No-lyrics handling — retry + message + visibility

**Files:**
- Modify: `Hum/LyricsEngine/LRCLIBSource.swift`
- Modify: `Hum/LyricsEngine/LyricsState.swift`
- Modify: `Hum/Views/HumWindowView.swift`
- Modify: `Hum/StatusBar/StatusBarController.swift`

- [ ] **Step 1: Replace `Hum/LyricsEngine/LRCLIBSource.swift`**

```swift
import Foundation

struct LRCLIBSource: LyricsSource {
    func fetchSyncedLyrics(for track: Track) async -> String? {
        // Try with full info (title + artist + album)
        if let result = await request(title: track.title, artist: track.artist, album: track.album),
           !result.isEmpty {
            return result
        }
        // Fallback: try without album name
        return await request(title: track.title, artist: track.artist, album: nil)
    }

    private func request(title: String, artist: String, album: String?) async -> String? {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        var queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        if let album = album {
            queryItems.append(URLQueryItem(name: "album_name", value: album))
        }
        components.queryItems = queryItems
        guard let url = components.url else { return nil }

        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("Hum macOS app", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: req),
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

- [ ] **Step 2: Add `noLyricsFound` to `Hum/LyricsEngine/LyricsState.swift`**

```swift
import Foundation

@MainActor
final class LyricsState: ObservableObject {
    @Published var lines: [LyricLine] = []
    @Published var syncOffset: TimeInterval = 0
    @Published var isManuallyHidden: Bool = false
    @Published var noLyricsFound: Bool = false
}
```

- [ ] **Step 3: Update `Hum/Views/HumWindowView.swift`**

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
}
```

- [ ] **Step 4: Update `observe()` in `Hum/StatusBar/StatusBarController.swift`**

Find the current `CombineLatest3` subscription in `observe()` (lines 104–113) and replace it:

```swift
        let hasContentPublisher = lyricsState.$lines
            .combineLatest(lyricsState.$noLyricsFound)
            .map { lines, noLyrics in !lines.isEmpty || noLyrics }

        Publishers.CombineLatest3(musicObserver.$isPlaying, hasContentPublisher, lyricsState.$isManuallyHidden)
            .sink { [weak self] isPlaying, hasContent, isHidden in
                guard let self else { return }
                if isPlaying && hasContent && !isHidden {
                    self.windowManager.show()
                } else {
                    self.windowManager.hide()
                }
            }
            .store(in: &cancellables)
```

The window now shows when `isPlaying && (hasLyrics OR noLyricsFound) && !isManuallyHidden`.

- [ ] **Step 5: Update `handleTrackChange` in `StatusBarController.swift`**

Find the current `handleTrackChange` method (lines 122–133) and replace it:

```swift
    private func handleTrackChange(_ track: Track?) async {
        guard let track else {
            lyricsState.lines = []
            lyricsState.noLyricsFound = false
            return
        }
        lyricsState.syncOffset = 0
        lyricsState.noLyricsFound = false
        lyricsState.isManuallyHidden = false
        if let stepper = statusItem.menu?.item(at: 1)?.view as? NSStepper {
            stepper.doubleValue = 0
        }
        statusItem.menu?.item(withTag: 1)?.title = "Sync Offset: +0.0s"
        let lines = await lyricsEngine.fetch(for: track)
        guard !Task.isCancelled else { return }
        lyricsState.lines = lines
        lyricsState.noLyricsFound = lines.isEmpty
    }
```

Key changes: `noLyricsFound` is reset to `false` at start, then set to `lines.isEmpty` after fetch.

- [ ] **Step 6: Build + run tests**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(Test Suite.*passed|FAIL|error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`, all 18 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add Hum/LyricsEngine/LRCLIBSource.swift Hum/LyricsEngine/LyricsState.swift Hum/Views/HumWindowView.swift Hum/StatusBar/StatusBarController.swift
git commit -m "feat: LRCLIB retry without album, no-lyrics message, window shows when noLyricsFound"
```

---

### Task 3: Auto-show on New Track menu toggle

**Files:**
- Modify: `Hum/StatusBar/StatusBarController.swift`

- [ ] **Step 1: Add `autoShowOnNewTrack` computed property to `StatusBarController`**

Add this after the `private var fetchTask` line (line 8):

```swift
    private var autoShowOnNewTrack: Bool {
        get { UserDefaults.standard.bool(forKey: "humAutoShowOnNewTrack") }
        set { UserDefaults.standard.set(newValue, forKey: "humAutoShowOnNewTrack") }
    }
```

- [ ] **Step 2: Add "Auto-show on New Track" menu item to `buildMenu()`**

Find the current `loginItem` block in `buildMenu()`. After `menu.addItem(loginItem)`, add:

```swift
        let autoShowItem = NSMenuItem(
            title: "Auto-show on New Track",
            action: #selector(toggleAutoShow),
            keyEquivalent: ""
        )
        autoShowItem.tag = 3
        autoShowItem.state = autoShowOnNewTrack ? .on : .off
        autoShowItem.target = self
        menu.addItem(autoShowItem)
```

- [ ] **Step 3: Add `toggleAutoShow` action to `StatusBarController`**

Add after `toggleLyricsVisibility`:

```swift
    @objc private func toggleAutoShow() {
        autoShowOnNewTrack = !autoShowOnNewTrack
        statusItem.menu?.item(withTag: 3)?.state = autoShowOnNewTrack ? .on : .off
    }
```

- [ ] **Step 4: Update `handleTrackChange` to use conditional reset**

Find `lyricsState.isManuallyHidden = false` in `handleTrackChange` (set in Task 2). Replace with:

```swift
        if autoShowOnNewTrack {
            lyricsState.isManuallyHidden = false
        }
```

- [ ] **Step 5: Build + run tests**

```bash
xcodebuild build -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(error:|BUILD)"
xcodebuild test -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "(Test Suite.*passed|FAIL|error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`, all 18 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add Hum/StatusBar/StatusBarController.swift
git commit -m "feat: Auto-show on New Track menu toggle, default off"
```
