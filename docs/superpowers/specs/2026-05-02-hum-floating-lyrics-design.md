# Hum — Floating Lyrics App: Design Spec

**Date:** 2026-05-02  
**Platform:** macOS 13+ (Ventura and later)  
**Stack:** SwiftUI + AppKit hybrid, single app target

---

## Overview

Hum is a native macOS menu bar app that displays real-time karaoke-style floating lyrics while Apple Music is playing. The floating window is always-on-top, auto-shows when music plays, auto-hides when paused or stopped, and can be freely repositioned by the user.

---

## Architecture

Single app target with four clearly bounded modules:

```
HumApp
├── MusicObserver       — polls Apple Music state via AppleScript
├── LyricsEngine        — fetches, caches, and parses synced lyrics
├── KaraokeView         — SwiftUI karaoke rendering with animated highlight
└── WindowManager       — AppKit NSPanel, always-on-top, drag + persist position
```

**Status bar:** `NSStatusItem` with a music note icon. Menu exposes Show/Hide toggle and Quit. This is the bridge between AppKit and SwiftUI.

---

## Components

### MusicObserver

- Polls Apple Music via AppleScript at 500ms intervals
- Reads: track name, artist, album, player state (playing/paused/stopped), playback position (seconds)
- Publishes `currentTrack: Track?` and `playbackPosition: TimeInterval` via `@Published`
- Triggers `WindowManager` show/hide based on player state
- When Apple Music is not running: stays idle, window stays hidden

### LyricsEngine

- **Primary source:** MusicKit framework — fetches synced lyrics Apple Music has natively (requires user permission on first launch)
- **Fallback:** LRCLIB API (`lrclib.net`) — free, no API key required, supports synced `.lrc` lyrics
- Parses `.lrc` format into `[LyricLine(timestamp: TimeInterval, text: String)]`
- In-memory cache per session — skips re-fetch when same track is playing
- If MusicKit permission is denied: skips silently to LRCLIB, does not re-prompt
- If no lyrics found from either source: stores `nil`, triggers "no lyrics" state (window hidden)

### KaraokeView

- SwiftUI `ScrollView` + `VStack` of lyric lines
- **Active line:** larger font, bright white, animated with `withAnimation(.easeInOut)`
- **Inactive lines:** dimmed to 0.4 opacity, smaller font
- Auto-scrolls to active line using `ScrollViewReader`
- Background: `NSVisualEffectView` with vibrancy dark material via `NSViewRepresentable`
- Active line determined by comparing `playbackPosition` against `LyricLine.timestamp` array

### WindowManager

- Uses `NSPanel` with `.nonactivatingPanel` style — floats above all windows without stealing focus
- Window level: `NSWindowLevel.floating`
- Drag-to-reposition via `mouseDragged` on the panel
- Saves window position to `UserDefaults` on drag end; restores on next launch
- Default position on first launch: bottom center of main screen
- Responds to `MusicObserver` state: animates in on play, animates out on pause/stop

---

## Data Flow

```
Apple Music playing
  → MusicObserver detects track change + playback position (every 500ms)
  → LyricsEngine.fetch(track)
      a. Cache hit → return immediately
      b. Try MusicKit → success → parse + cache
      c. MusicKit fails / no lyrics → try LRCLIB API
      d. LRCLIB fails → store nil, show "no lyrics" state
  → KaraokeView receives [LyricLine], starts rendering
  → Every 500ms: playbackPosition update → find active line → animate highlight
  → Track paused / stopped → WindowManager hides panel
  → Track changed → repeat from top
```

---

## Error Handling

| Situation | Behavior |
|---|---|
| Apple Music not running | MusicObserver stays idle, window hidden |
| Track has no lyrics | Window hidden, no error shown |
| LRCLIB timeout / offline | Graceful fallback to no-lyrics state; retry on next track |
| MusicKit permission denied | Silently skip to LRCLIB, do not re-prompt |
| Lyrics timing off-sync | User can adjust ±5s offset via slider in status bar menu |

---

## Privacy

- No user data is stored or transmitted beyond track title + artist name to LRCLIB for lookup
- No analytics, no crash reporting, no disk logging

---

## Testing Strategy

**Unit tests:**
- `LyricsEngine` — `.lrc` parser with sample files covering edge cases (empty lines, timestamps without text, multi-digit timestamps)
- `MusicObserver` — state machine transitions (playing → paused → stopped → playing)
- `KaraokeView` — `activeLine` computation logic given a playback position and `[LyricLine]`

**Integration tests:**
- `LyricsEngine` fetch flow — mock network layer, verify MusicKit → LRCLIB fallback works correctly
- Cache behavior — verify no re-fetch for the same track

**Manual testing checklist:**
- Play/pause in Apple Music → window shows/hides correctly
- Track change → lyrics update without flicker
- Drag window → position persists after relaunch
- Track without lyrics → no crash, window hidden
- Offline → LRCLIB timeout handled gracefully
- Multiple displays → window appears on correct display

UI snapshot tests are explicitly out of scope — karaoke animation is too dynamic to snapshot meaningfully.
