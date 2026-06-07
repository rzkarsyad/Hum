# LRCLIB Search Fallback — Design

**Date:** 2026-06-07
**Status:** Approved design, ready for implementation plan
**Branch:** `feat/lrclib-search-fallback`

## Goal

Increase the synced-lyrics match rate across all sources (Apple Music, Spotify,
and especially browser/YouTube Music) by adding a **`/api/search` fallback** to
`LRCLIBSource` when the exact-match `/api/get` attempts return nothing — without
ever showing lyrics for the wrong song.

## Background

`LRCLIBSource.fetchSyncedLyricsWithError` currently makes two **exact-match**
`/api/get` calls (track + artist + album + duration, then without album).
`/api/get` uses signature matching; if the album/duration/title don't line up it
returns 404 — even when the track's synced lyrics exist on LRCLIB and are
reachable via `/api/search`. This was observed during the browser-media work:
metadata from the browser (e.g., empty album) made `/api/get` miss songs that
`/api/search` finds easily.

## Decisions (locked during brainstorming)

1. **Synced only.** The fallback accepts only results with non-empty
   `syncedLyrics`. If a song has only `plainLyrics`, show nothing (unchanged
   behavior). No UI changes — Hum stays a synced-karaoke app.
2. **Safe/strict matching.** A result is accepted only when its title *and*
   artist match the track (normalized, case-insensitive, equal-or-contains).
   Wrong lyrics are worse than no lyrics, so when nothing matches confidently we
   return no lyrics.
3. **Approach A** — normalized title+artist gate + duration tiebreak (not scored
   ranking, not duration-anchored). Title+artist is the safety gate; duration
   only disambiguates among already-matching candidates and is optional.

## Components

### `LRCLIBSource` (modified) — `Hum/LyricsEngine/LRCLIBSource.swift`

`fetchSyncedLyricsWithError` gains a **third attempt** after the two `/api/get`
calls:

1. `/api/get` with album + duration (existing)
2. `/api/get` without album (existing)
3. **`/api/search`** → `bestSyncedMatch(...)` (new)

```
get(album, duration)  → synced? → return
get(nil, duration)    → synced? → return
search(title, artist) → bestSyncedMatch → matched? → return
otherwise             → notFound  (or networkError if the request failed)
```

New private method `searchRequest(title:artist:)`:
- GET `https://lrclib.net/api/search?track_name=<title>&artist_name=<artist>`
- Same `User-Agent: Hum macOS app` header and 10 s timeout as `request`.
- Decodes a JSON array of `LRCLIBSearchResult`.
- Returns `Result<[LRCLIBSearchResult], Error>` — `.failure` only on a real
  request/transport error (so the engine can still surface `networkError`).

### Pure helpers (top-level, unit-tested)

- **`normalizeForMatch(_ s: String) -> String`** — lowercase, trim, fold
  diacritics (`folding(options: [.diacriticInsensitive, .caseInsensitive], …)`),
  collapse internal whitespace. No aggressive parenthetical stripping —
  equal-or-contains handles common suffixes like "(Official Audio)".
- **`bestSyncedMatch(results:title:artist:duration:) -> String?`**
  1. Keep results with non-empty `syncedLyrics`.
  2. Keep those where `normalizeForMatch(artist)` and the candidate's normalized
     `artistName` are equal **or** one contains the other — and the same for
     title vs `trackName`. (Both title and artist must pass.)
  3. If none remain → `nil`.
  4. If `duration` is provided → return the surviving candidate with the smallest
     `|duration − candidate.duration|`; otherwise → the first survivor.
  5. Return that candidate's `syncedLyrics`.

### Types

```
struct LRCLIBSearchResult: Decodable {
    let trackName: String
    let artistName: String
    let duration: Double?
    let syncedLyrics: String?
}
```

(`LyricsEngine`, `LyricsState`, views, and `MusicKitSource` are unchanged.)

## Data flow & error handling

- The search step runs **only** when both `/api/get` attempts yield no synced
  lyrics — so it adds at most one extra request, and only for tracks that are
  currently failing.
- Network/transport error on the search request → return `.failure(error)` so
  `LyricsEngine` reports `networkError` (the existing "Can't reach lyrics server"
  state). If the server is reachable but nothing matches → `.success(nil)`
  (`notFound`).
- HTTP non-200 on search → treat as no results (`.success([])`), consistent with
  how `request` treats non-200 for `/api/get`.

## Testing

**Unit (pure, TDD):**
- `normalizeForMatch`: lowercasing, trimming, diacritics folding, whitespace
  collapse.
- `bestSyncedMatch`:
  - exact title+artist match is returned
  - two same-title candidates → the one closest in duration wins
  - artist mismatch → rejected (returns nil)
  - candidate without `syncedLyrics` → skipped
  - no title/artist match → nil
  - missing track duration → first surviving match returned
  - equal-or-contains: "Curious" matches "Curious (Sped Up)"

**Manual / integration:**
- A track known to fail `/api/get` but present via `/api/search` (e.g. a browser
  track with empty album) now shows synced lyrics.
- A nonsense/mismatched track still shows nothing (no wrong lyrics).
- Offline → still reports the network-error state.

## Scope / non-goals

- No plain-lyrics display mode.
- No change to `/api/get` behavior or the primary `MusicKitSource`.
- No fix here for the pre-existing "network error is cached as notFound until
  relaunch" behavior in `LyricsEngine` (noted as a separate concern).
- No new external dependencies.
