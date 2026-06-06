# Hum

Floating karaoke lyrics for Apple Music, Spotify & browsers — always on top, always in sync.

![Hum screenshot](docs/screenshot.png)

---

## Features

- **Works with Apple Music, Spotify & browsers** — detects whichever is playing; browser support (YouTube Music / music videos) via the system Now Playing bridge
- **Real-time synced lyrics** — fetches timestamped lyrics from [LRCLIB](https://lrclib.net), auto-matched to the current track
- **Floating window** — stays above every app, draggable, resizable
- **Smooth karaoke scroll** — active line always centered, proximity fade on surrounding lines
- **Always on top** — works across all Spaces and fullscreen apps
- **Adjustable font size** — via menu bar icon
- **Hide / show** — hide the window once, it stays hidden until you manually show it again
- **Launch at login** — optional, configurable from menu bar
- **Lightweight** — pure macOS, no Electron, ~2.5 MB

---

## Requirements

- macOS 15.0 (Sequoia) or later
- Apple Music, Spotify, or a supported browser (Chrome, Safari, Arc, Brave, Edge, Firefox)

---

## Install

### Homebrew (recommended)

```bash
brew install --cask --no-quarantine rzkarsyad/hum/hum
```

The `--no-quarantine` flag bypasses Gatekeeper — required because Hum is not notarized by Apple.

### Direct Download

Download the latest `Hum.dmg` from [Releases](https://github.com/rzkarsyad/Hum/releases), open it, and drag Hum to Applications.

> **Note:** Because Hum is not notarized, macOS may block it on first open. Go to **System Settings → Privacy & Security → Open Anyway**.

---

## Usage

1. Open Hum — it appears as a **♪** icon in the menu bar, no Dock icon
2. Play any track in Apple Music or Spotify
3. The floating window appears automatically with synced lyrics
4. **Hide** the window via the **👁** button or menu bar → Hide Lyrics
5. **Show** it again via menu bar → Show Lyrics
6. Adjust **font size** and other settings from the menu bar icon

---

## Privacy

Hum does not collect or transmit any personal data. See [PRIVACY.md](PRIVACY.md) for details.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

---

## License

MIT
