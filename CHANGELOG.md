# Changelog

All notable changes to Hum are documented here.

## [Unreleased]

### Added

- **Spotify support** — Hum now detects the currently playing track from Spotify in addition to Apple Music, automatically showing synced lyrics for whichever app is playing. Apple Music takes priority when both are playing. (macOS will prompt once for Automation access to Spotify the first time it's read.)
- **Browser media support** — Hum now shows synced lyrics for music played in a browser (YouTube Music and music videos), via the macOS Now Playing system (bundled `ungive/mediaremote-adapter`, BSD-3). The window stays hidden for non-music browser media. Apple Music / Spotify keep priority.

## [1.0.0] — 2026-05-19

### Initial release

- Real-time synced lyrics from LRCLIB, auto-matched to Apple Music
- Floating always-on-top window, draggable and resizable
- Smooth karaoke scroll with proximity fade and scale animation
- Edge fade mask on lyrics scroll view
- Window fade in/out when playback starts/stops
- Artwork crossfade on track change
- Hide/show from window button or menu bar — stays hidden across track changes until manually shown
- Adjustable font size via menu bar stepper
- Launch at login support
- Lightweight background polling with interpolated 60fps position tracking
