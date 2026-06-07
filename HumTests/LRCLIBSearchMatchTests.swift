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
}
