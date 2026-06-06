# Browser Media Detection (YouTube / YouTube Music) — Design

**Date:** 2026-06-07
**Status:** Approved design, ready for implementation plan
**Branch:** `feat/browser-media-detection`

## Goal

Let Hum show synced lyrics for music played in a **browser** (YouTube Music, or
music videos on YouTube), in addition to the existing Apple Music and Spotify
support.

## Background / Why this is different

Apple Music and Spotify expose now-playing info via AppleScript, which Hum's
`MusicObserver` polls every 500 ms. **Browsers do not.** The only system-wide
source that includes browser media is Apple's private **MediaRemote** framework
(`MRMediaRemoteGetNowPlayingInfo`), which Apple **locked behind an entitlement in
macOS 15.4+** — direct access from a third-party app like Hum is denied. Target
machine is macOS 26.5, so direct MediaRemote is not available.

**Chosen workaround:** the BSD-3-licensed [`ungive/mediaremote-adapter`](https://github.com/ungive/mediaremote-adapter),
which reads now-playing through `/usr/bin/perl` (a system binary that retains the
MediaRemote entitlement) plus a small helper framework that streams JSON to
stdout. Hum is not sandboxed and is distributed via Homebrew / direct download
(no App Store review), so a private-framework workaround is acceptable.

## Decisions (locked during brainstorming)

1. **Mechanism:** MediaRemote adapter (perl helper), not browser JS injection.
2. **Architecture:** MediaRemote is an **additional, browser-only source**.
   Apple Music & Spotify keep their precise AppleScript path. Risk is isolated —
   if Apple breaks MediaRemote, only the browser feature degrades.
3. **UX:** For browser sources, the lyrics window appears **only when synced
   lyrics are actually found**. It stays hidden for ordinary videos, podcasts,
   Netflix, etc. (Apple Music / Spotify keep current behavior, including the
   "No lyrics found" state.)

## Adapter interface (from upstream README)

- Invocation: `/usr/bin/perl <mediaremote-adapter.pl> <MediaRemoteAdapter.framework> stream`
  - `stream` — continuous NDJSON updates until SIGTERM
  - `get` — one-shot JSON
  - `test` — exit code 0 if the adapter works on this machine
- JSON fields: `bundleIdentifier`, `parentApplicationBundleIdentifier`,
  `playing` (bool), `title`, `artist`, `album`, `duration`, `elapsedTime`,
  `timestamp`, `playbackRate`, `artworkMimeType`, `artworkData` (base64),
  `isMusicApp`, … Mandatory non-null: `bundleIdentifier`, `playing`, `title`.
- Artwork: base64 in `artworkData` (may load late / be absent — handle gracefully).
- License: BSD 3-Clause (redistributable with attribution).
- Bundle: `MediaRemoteAdapter.framework` (universal arm64 + x86_64),
  `mediaremote-adapter.pl`, optional `MediaRemoteAdapterTestClient`. The
  framework is passed as a script argument, **not linked** against the app.

## Components

### `BrowserMediaSource` (new) — `Hum/MusicObserver/BrowserMediaSource.swift`

Single purpose: *"what's playing in a browser, per MediaRemote."*

- **Owns** an `/usr/bin/perl … stream` subprocess (`Foundation.Process`), reading
  stdout line by line.
- Each line → `parseBrowserNowPlaying(_:)` (pure). Filters to browser bundle IDs
  via `isBrowserBundleID(_:)` (checks both `bundleIdentifier` and
  `parentApplicationBundleIdentifier`). Non-browser entries → ignored (`nil`).
- Maintains `latestSnapshot: BrowserSnapshot?` (thread-safe). `nil` when no
  browser media is playing.
- Lifecycle: `start()` runs `test` first; on success spawns `stream`. `stop()`
  sends SIGTERM. If the subprocess exits unexpectedly → restart with capped
  backoff.
- **Interface consumed by `MusicObserver`:** a thread-safe read of the current
  snapshot (with a freshly computed position).

```
struct BrowserSnapshot: Equatable {
    let bundleID: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval?
    let isPlaying: Bool
    let elapsedTime: TimeInterval
    let timestamp: Date         // when elapsedTime was sampled
    let playbackRate: Double
    let artworkData: Data?      // decoded from base64
    func position(at now: Date) -> TimeInterval   // elapsedTime + (now - timestamp) * rate
}
```

### Pure, testable helpers (top-level, like `isSeek` / `parsePollResult`)

- `parseBrowserNowPlaying(_ jsonLine: String) -> BrowserSnapshot?` — decode one
  NDJSON line; return `nil` for non-browser apps, not-playing, or malformed input.
- `isBrowserBundleID(_ id: String) -> Bool` — allowlist: `com.google.Chrome`
  (+ canary/dev/beta), `com.apple.Safari` (+ Technology Preview),
  `company.thebrowser.Browser` (Arc), `com.brave.Browser` (+ beta/nightly),
  `com.microsoft.edgemac`, `org.mozilla.firefox`, `com.operasoftware.Opera`,
  `com.vivaldi.Vivaldi`, `ru.yandex.desktop.yandex-browser`.
- `mergeOutcome(appleScript: PollOutcome, browser: BrowserSnapshot?, at: Date) -> PollOutcome`
  — priority **Apple Music ▸ Spotify ▸ Browser** (a *playing* source wins). A
  playing browser snapshot becomes `.playing(PollResult(source: .browser, …))`.

### `MusicObserver` (modified) — `Hum/MusicObserver/MusicObserver.swift`

- Add `.browser` to `PlayerSource` (raw value `"browser"`).
- Hold an injected `BrowserMediaSource`; `start()`/`stop()` propagate to it.
- In the 500 ms poll: compute the AppleScript `PollOutcome`, read the browser
  snapshot, and combine via `mergeOutcome(...)`. Feed the winning position into
  the existing `basePosition`/`baseDate` interpolation unchanged.
- Make `currentSource` `@Published` so the UI can branch on it.
- Artwork: when the winning source is `.browser`, decode `artworkData` →
  `NSImage` (no AppleScript). Refresh when `artworkData` changes for the same
  track (covers the "artwork loads late" caveat).

### `StatusBarController` (modified) — visibility honors source

`hasContent` becomes source-aware:
- `currentSource == .browser` → `hasContent = !lines.isEmpty` (ignore
  `noLyricsFound` / `networkError` → stay hidden for non-music browser media).
- otherwise → unchanged: `!lines.isEmpty || noLyricsFound || networkError`.

Requires folding `musicObserver.$currentSource` into the existing
`CombineLatest` visibility chain.

### Lyrics — unchanged

Browser tracks flow through the same `LyricsEngine` → LRCLIB fetch by
title/artist. YT Music reports a real song title/artist → matches. Ordinary
videos → no match → window stays hidden (per UX decision).

## Bundling & build (`project.yml` / xcodegen)

- Add the three adapter files under `Hum/Vendor/MediaRemoteAdapter/` and copy
  them into the app bundle (Resources or a known subdir). Resolve paths at
  runtime via `Bundle.main`.
- Framework is **not** linked / embedded as a dependency — it is only passed as
  a perl argument.
- Ad-hoc code signing (`CODE_SIGN_IDENTITY: "-"`), consistent with the app.
- Include upstream `LICENSE` (BSD-3) with attribution.

## Error handling & graceful degradation

- Startup `test` fails (perl missing, Apple tightened the lock, framework
  unusable) → **disable the browser source silently**, log once. Apple Music /
  Spotify are unaffected.
- Subprocess crash/exit → restart with capped exponential backoff; give up after
  ~5 consecutive failures and degrade as above.
- Malformed/partial JSON line → skip that line, keep streaming.
- Missing optional fields (artist/album/duration/artwork) → tolerate; only
  `bundleIdentifier`/`playing`/`title` are guaranteed.

## Testing

**Unit (pure functions):**
- `parseBrowserNowPlaying`: browser playing; paused; non-browser app → nil;
  missing optional fields; artwork present/absent; malformed JSON → nil.
- `isBrowserBundleID`: known browsers true; Music/Spotify/random false; match via
  `parentApplicationBundleIdentifier`.
- `mergeOutcome`: priority ordering; browser wins when AppleScript stopped;
  Apple Music/Spotify override browser; nothing playing → stopped.

**Manual:**
- YT Music track → window + synced lyrics + artwork.
- Ordinary YouTube video / podcast / Netflix → window stays hidden.
- Switch Apple Music ↔ Spotify ↔ browser → correct source wins, no flicker.
- Quit/restart with `test` forced to fail → app still works for Music/Spotify.

## Risks & caveats

- **Private-framework workaround** — may break on a future macOS. Isolated to the
  browser feature by design.
- **Depends on `/usr/bin/perl`** — present on macOS 26 but Apple is deprecating
  bundled scripting runtimes; handled by graceful degradation.
- **Browser position/artwork accuracy** varies (MediaRemote sampling + late
  artwork).
- **License compliance** — bundle BSD-3 LICENSE + attribution.

## Scope / non-goals

- No browser extension; no JS injection.
- No media *control* (play/pause/seek) from Hum — read-only now-playing.
- No replacement of the existing AppleScript path for Apple Music / Spotify.
- Lyrics availability for arbitrary YouTube videos is out of scope (depends on
  LRCLIB having the track).
