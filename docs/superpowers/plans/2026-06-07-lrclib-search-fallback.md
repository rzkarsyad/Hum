# LRCLIB Search Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the exact-match `/api/get` calls find no synced lyrics, fall back to LRCLIB `/api/search` and safely pick a title+artist-matching result — raising the synced-lyrics match rate without ever showing the wrong song's lyrics.

**Architecture:** Add a third attempt to `LRCLIBSource.fetchSyncedLyricsWithError` (after the two `/api/get` calls): query `/api/search`, then run a pure, unit-tested matcher (`bestSyncedMatch`) that filters to results with synced lyrics, gates on normalized title+artist (equal-or-contains), and uses duration only as a tiebreak. `LyricsEngine`, views, and the primary source are unchanged.

**Tech Stack:** Swift 5.9, Foundation (URLSession, JSONDecoder), XCTest, xcodegen.

**Spec:** `docs/superpowers/specs/2026-06-07-lrclib-search-fallback-design.md`

**Base branch:** `feat/lrclib-search-fallback` (off `main`).

---

## File Structure

- **Modify** `Hum/LyricsEngine/LRCLIBSource.swift` — add top-level `normalizeForMatch` and `bestSyncedMatch`, the `LRCLIBSearchResult` type, a private `searchRequest`, and wire the third attempt into `fetchSyncedLyricsWithError`.
- **Create** `HumTests/LRCLIBSearchMatchTests.swift` — unit tests for the two pure functions.

---

## Task 1: `normalizeForMatch` (pure)

**Files:**
- Modify: `Hum/LyricsEngine/LRCLIBSource.swift`
- Test: `HumTests/LRCLIBSearchMatchTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `HumTests/LRCLIBSearchMatchTests.swift`:

```swift
import XCTest
@testable import Hum

final class LRCLIBSearchMatchTests: XCTestCase {

    func test_normalize_lowercasesAndTrims() {
        XCTAssertEqual(normalizeForMatch("  Hello World  "), "hello world")
    }

    func test_normalize_collapsesInnerWhitespace() {
        XCTAssertEqual(normalizeForMatch("Hello    World"), "hello world")
    }

    func test_normalize_foldsDiacritics() {
        XCTAssertEqual(normalizeForMatch("Beyoncé"), "beyonce")
    }
}
```

- [ ] **Step 2: Register the new test file in the project**

Run: `xcodegen generate`
Expected: `Created project at .../Hum.xcodeproj`

- [ ] **Step 3: Run the tests to verify they fail**

Run: `xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/LRCLIBSearchMatchTests 2>&1 | tail -15`
Expected: compile failure — `cannot find 'normalizeForMatch' in scope`.

- [ ] **Step 4: Implement `normalizeForMatch`**

Add to the top of `Hum/LyricsEngine/LRCLIBSource.swift`, right after `import Foundation` (before `struct LRCLIBSource`):

```swift
/// Normalize a title/artist for fuzzy comparison: case- and diacritic-insensitive,
/// with collapsed whitespace. Used to safely match `/api/search` results.
func normalizeForMatch(_ s: String) -> String {
    s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/LRCLIBSearchMatchTests 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`, 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add Hum/LyricsEngine/LRCLIBSource.swift HumTests/LRCLIBSearchMatchTests.swift Hum.xcodeproj
git commit -m "feat: normalizeForMatch helper for fuzzy lyric matching"
```

---

## Task 2: `LRCLIBSearchResult` + `bestSyncedMatch` (pure)

**Files:**
- Modify: `Hum/LyricsEngine/LRCLIBSource.swift`
- Test: `HumTests/LRCLIBSearchMatchTests.swift`

- [ ] **Step 1: Write the failing tests**

Add these inside the `LRCLIBSearchMatchTests` class in `HumTests/LRCLIBSearchMatchTests.swift`:

```swift
    private func r(_ track: String, _ artist: String, _ dur: Double?, synced: String?) -> LRCLIBSearchResult {
        LRCLIBSearchResult(trackName: track, artistName: artist, duration: dur, syncedLyrics: synced)
    }

    func test_match_exactReturnsSynced() {
        let results = [r("Curious", "AND2BLE", 178, synced: "[00:01.00]hi")]
        XCTAssertEqual(
            bestSyncedMatch(results: results, title: "Curious", artist: "AND2BLE", duration: 180),
            "[00:01.00]hi")
    }

    func test_match_durationTiebreak() {
        let results = [
            r("Song", "Artist", 200, synced: "LONG"),
            r("Song", "Artist", 181, synced: "CLOSE"),
        ]
        XCTAssertEqual(
            bestSyncedMatch(results: results, title: "Song", artist: "Artist", duration: 180),
            "CLOSE")
    }

    func test_match_artistMismatchRejected() {
        let results = [r("Song", "Other Artist", 180, synced: "X")]
        XCTAssertNil(bestSyncedMatch(results: results, title: "Song", artist: "Artist", duration: 180))
    }

    func test_match_skipsResultsWithoutSynced() {
        let results = [
            r("Song", "Artist", 180, synced: nil),
            r("Song", "Artist", 180, synced: ""),
        ]
        XCTAssertNil(bestSyncedMatch(results: results, title: "Song", artist: "Artist", duration: 180))
    }

    func test_match_noTitleMatchReturnsNil() {
        let results = [r("Totally Different", "Artist", 180, synced: "X")]
        XCTAssertNil(bestSyncedMatch(results: results, title: "Song", artist: "Artist", duration: 180))
    }

    func test_match_missingDurationTakesFirstMatch() {
        let results = [
            r("Song", "Artist", 200, synced: "FIRST"),
            r("Song", "Artist", 181, synced: "SECOND"),
        ]
        XCTAssertEqual(
            bestSyncedMatch(results: results, title: "Song", artist: "Artist", duration: nil),
            "FIRST")
    }

    func test_match_containsHandlesSuffix() {
        let results = [r("Curious (Sped Up)", "AND2BLE", 150, synced: "X")]
        XCTAssertEqual(
            bestSyncedMatch(results: results, title: "Curious", artist: "AND2BLE", duration: nil),
            "X")
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/LRCLIBSearchMatchTests 2>&1 | tail -15`
Expected: compile failure — `cannot find 'LRCLIBSearchResult'` / `cannot find 'bestSyncedMatch'`.

- [ ] **Step 3: Implement the type and matcher**

Add to `Hum/LyricsEngine/LRCLIBSource.swift`, right after the `normalizeForMatch` function from Task 1:

```swift
struct LRCLIBSearchResult: Decodable, Equatable {
    let trackName: String
    let artistName: String
    let duration: Double?
    let syncedLyrics: String?
}

/// Pick the best synced-lyrics result for a track, or nil if none match safely.
/// A result qualifies only when both its title and artist match (normalized,
/// equal-or-contains). Duration is used only to break ties among matches.
func bestSyncedMatch(results: [LRCLIBSearchResult], title: String, artist: String, duration: TimeInterval?) -> String? {
    func matches(_ a: String, _ b: String) -> Bool {
        let na = normalizeForMatch(a), nb = normalizeForMatch(b)
        guard !na.isEmpty, !nb.isEmpty else { return false }
        return na == nb || na.contains(nb) || nb.contains(na)
    }

    let candidates = results.filter {
        guard let synced = $0.syncedLyrics, !synced.isEmpty else { return false }
        return matches($0.trackName, title) && matches($0.artistName, artist)
    }
    guard !candidates.isEmpty else { return nil }

    guard let duration else { return candidates.first?.syncedLyrics }
    return candidates.min {
        abs(($0.duration ?? .greatestFiniteMagnitude) - duration) <
        abs(($1.duration ?? .greatestFiniteMagnitude) - duration)
    }?.syncedLyrics
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' -only-testing:HumTests/LRCLIBSearchMatchTests 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`, all 10 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Hum/LyricsEngine/LRCLIBSource.swift HumTests/LRCLIBSearchMatchTests.swift
git commit -m "feat: bestSyncedMatch — safe title+artist match with duration tiebreak"
```

---

## Task 3: `/api/search` request + wire the third attempt

**Files:**
- Modify: `Hum/LyricsEngine/LRCLIBSource.swift`

No unit test — this is networking/integration, verified by build + manual run.

- [ ] **Step 1: Add the `searchRequest` method**

In `Hum/LyricsEngine/LRCLIBSource.swift`, add this method inside `struct LRCLIBSource` (e.g. right after the existing `request(...)` method):

```swift
    private func searchRequest(title: String, artist: String) async -> Result<[LRCLIBSearchResult], Error> {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
        ]
        guard let url = components.url else { return .success([]) }

        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("Hum macOS app", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return .success([]) }
            let results = try JSONDecoder().decode([LRCLIBSearchResult].self, from: data)
            return .success(results)
        } catch {
            return .failure(error)
        }
    }
```

- [ ] **Step 2: Wire the third attempt into `fetchSyncedLyricsWithError`**

Replace the existing `fetchSyncedLyricsWithError` method (currently lines 8-12) with:

```swift
    func fetchSyncedLyricsWithError(for track: Track) async -> Result<String?, Error> {
        let first = await request(title: track.title, artist: track.artist, album: track.album, duration: track.duration)
        if case .success(let s) = first, let r = s, !r.isEmpty { return .success(r) }

        let second = await request(title: track.title, artist: track.artist, album: nil, duration: track.duration)
        if case .success(let s) = second, let r = s, !r.isEmpty { return .success(r) }

        // Fallback: fuzzy /api/search, then a safe title+artist match.
        let search = await searchRequest(title: track.title, artist: track.artist)
        switch search {
        case .success(let results):
            if let matched = bestSyncedMatch(results: results, title: track.title, artist: track.artist, duration: track.duration),
               !matched.isEmpty {
                return .success(matched)
            }
            // No confident match. Preserve a network error from the 2nd get, else "not found".
            if case .failure(let e) = second { return .failure(e) }
            return .success(nil)
        case .failure(let e):
            return .failure(e)
        }
    }
```

- [ ] **Step 3: Build and run the full unit suite**

Run: `xcodebuild test -project Hum.xcodeproj -scheme Hum -destination 'platform=macOS' 2>&1 | grep -E "error:|Executed [0-9]+ tests|TEST SUCCEEDED|TEST FAILED" | tail -3`
Expected: `** TEST SUCCEEDED **`, all tests pass (existing + the 10 new match tests).

- [ ] **Step 4: Manual verification (real network)**

Confirm against a track that `/api/get` misses but `/api/search` finds. Quick CLI proxy for the logic:

```bash
# A real case from debugging: empty album made /api/get miss; search finds it.
curl -fsS "https://lrclib.net/api/search?track_name=Curious&artist_name=AND2BLE" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); s=[x for x in d if x.get('syncedLyrics')]; print(f'{len(s)} synced result(s); first match: {s[0][\"trackName\"]} — {s[0][\"artistName\"]}' if s else 'none')"
```
Expected: at least one synced result whose trackName/artistName match "Curious / AND2BLE".

Then in the running app: play that track (e.g. in a browser) and confirm the lyrics window now appears with synced lyrics. Play a nonsense track and confirm no (wrong) lyrics appear.

- [ ] **Step 5: Commit**

```bash
git add Hum/LyricsEngine/LRCLIBSource.swift
git commit -m "feat: LRCLIB /api/search fallback when exact-match get misses"
```

---

## Task 4: Docs

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add a changelog entry**

In `CHANGELOG.md`, add a new section directly under the title line `All notable changes to Hum are documented here.`:

```markdown
## [Unreleased]

### Changed

- **Better lyric matching** — when an exact lookup misses, Hum now falls back to LRCLIB search and safely matches by title + artist (with a duration tiebreak), finding synced lyrics for many more tracks — especially those played in a browser, where album/duration metadata is often incomplete.
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog for LRCLIB search fallback"
```

---

## Notes for the implementer

- `LRCLIBSearchResult` is `Decodable` with stored `let` properties, so Swift still
  synthesizes the internal memberwise initializer the tests use
  (`LRCLIBSearchResult(trackName:artistName:duration:syncedLyrics:)`).
- The search request fires **only** when both `/api/get` attempts return no synced
  lyrics, so it costs one extra request only for currently-failing tracks.
- Keep the `User-Agent: Hum macOS app` header and 10 s timeout consistent with the
  existing `request` method.
- Out of scope (do not touch): plain-lyrics display, the `LyricsEngine`
  network-error caching behavior, and `MusicKitSource`.
