# Privacy Policy

**Hum** is a macOS menu bar app that displays synced lyrics for tracks playing in Apple Music.

## What Hum accesses

| Data | Why | Stored? |
|------|-----|---------|
| Currently playing track (title, artist, album) | To fetch matching lyrics | No — read-only, never saved |
| Playback position | To sync lyrics in real time | No — read-only |
| Album artwork | To display in the lyrics window | No — held in memory only |

## Network requests

Hum makes outbound requests **only** to [LRCLIB](https://lrclib.net) to fetch timestamped lyrics for the current track. No other network requests are made. No analytics, no crash reporting, no telemetry.

## What Hum does NOT do

- Does not collect, store, or transmit personal data
- Does not access your music library files
- Does not track listening history
- Does not require an account or login

## Permissions

- **Apple Events / Automation** — required to read the currently playing track from Apple Music. macOS will prompt for this permission on first use.
- **Network access** — required to fetch lyrics from LRCLIB.

## Contact

Questions? Open an issue at [github.com/rzkarsyad/Hum/issues](https://github.com/rzkarsyad/Hum/issues).
