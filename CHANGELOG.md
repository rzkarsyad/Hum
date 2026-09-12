# Changelog

All notable changes to Hum are documented here.

## [Unreleased]

## [1.3.3] · 2026-09-12

### Fixed

- **Hum no longer keeps drawing the lyrics window while it is hidden.** Hiding the lyrics only took the window off screen; everything behind it carried on redrawing at full speed, so Hum still spent about half a CPU core and 100 MB of memory on something nobody could see. Hidden now costs about 2% of a core and 46 MB.
- **Much lower CPU and memory when idle.** With nothing playing, Hum now uses roughly half the CPU and a third less memory than before, which matters most for a menu bar app that stays open all day.
- **Lower CPU while lyrics are on screen.** The playback position was republished sixty times a second, forcing the whole window to lay out and redraw every frame even though only one line changes at a time. The window now redraws when something actually changes, cutting CPU use by roughly a fifth while lyrics are visible.

## [1.3.2] — 2026-09-12

### Fixed

- **The lyrics window can no longer disappear onto a monitor you unplugged** — if you moved Hum to an external display and then disconnected it, the window was restored to coordinates no attached screen covered. With no Dock icon and no window frame there was nothing left to click or drag, so Hum looked broken until its preferences were deleted by hand. The saved position is now checked against the displays you actually have, and brought back to the nearest one when it no longer fits.
- **Updating a music player no longer disables it until Hum restarts** — if Spotify or Apple Music was replaced while Hum was running, Hum could stop reading that player for the rest of the session.

## [1.3.1] — 2026-09-12

### Fixed

- **Browser lyrics no longer stop working after a long uptime** — the helper that reads browser playback is restarted automatically if it ever dies, but the retry budget was counted over the app's whole lifetime instead of per crash-loop. Five unrelated hiccups across days of uptime, each of which recovered on its own, would silently disable browser detection until Hum was restarted.

## [1.3.0] — 2026-09-12

### Fixed

- **Spotify is no longer required** — Hum polled Apple Music and Spotify from a single AppleScript, which forced macOS to resolve *both* apps when the script was compiled. On a Mac without Spotify (or without Apple Music) that popped a "Where is Spotify?" chooser panel and, once dismissed, left Hum unable to read *any* player — including the one that was installed. Each player is now polled by its own script, compiled only once that player is actually running, so Hum works with whichever players you happen to have.

### Changed

- **Better lyric matching** — when an exact lookup misses, Hum now falls back to LRCLIB search and safely matches by title + artist (with a duration tiebreak), finding synced lyrics for many more tracks — especially those played in a browser, where album/duration metadata is often incomplete.
- **Lyrics cached to disk** — fetched lyrics now persist across launches, so replaying a track shows lyrics instantly without re-fetching.
- **Snappier browser detection** — the lyrics window now appears the moment browser playback starts, instead of waiting for the next poll tick.

## [1.2.0] — 2026-06-07

### Added

- **Spotify support** — Hum now detects the currently playing track from Spotify in addition to Apple Music, automatically showing synced lyrics for whichever app is playing. Apple Music takes priority when both are playing. (macOS will prompt once for Automation access to Spotify the first time it's read.)
- **Browser media support** — Hum now shows synced lyrics for music played in a browser (YouTube Music and music videos), via the macOS Now Playing system (bundled `ungive/mediaremote-adapter`, BSD-3). The window stays hidden for non-music browser media. Apple Music / Spotify keep priority.

### Changed

- **Liquid Glass controls** — the collapse and hide buttons are now native Liquid Glass buttons on macOS 26+, with a subtle material fallback on earlier systems.
- **Smoother collapse/expand** — the minimized bar animates with a gentle spring bounce, and the chevron icon transitions between states.

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
