import XCTest
@testable import Hum

final class LyricsEngineTests: XCTestCase {

    private struct MockSource: LyricsSource {
        let result: String?
        func fetchSyncedLyrics(for track: Track) async -> String? { result }
    }

    private let track = Track(title: "Test", artist: "Artist", album: "Album")
    private let sampleLRC = "[00:01.00] Hello\n[00:02.00] World"

    func test_returnsParsedLinesOnSuccess() async {
        let engine = LyricsEngine(primary: MockSource(result: sampleLRC), fallback: MockSource(result: nil))
        let lines = await engine.fetch(for: track)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].text, "Hello")
    }

    func test_fallsBackWhenPrimaryReturnsNil() async {
        let engine = LyricsEngine(primary: MockSource(result: nil), fallback: MockSource(result: sampleLRC))
        let lines = await engine.fetch(for: track)
        XCTAssertEqual(lines.count, 2)
    }

    func test_returnsEmptyWhenBothSourcesFail() async {
        let engine = LyricsEngine(primary: MockSource(result: nil), fallback: MockSource(result: nil))
        let lines = await engine.fetch(for: track)
        XCTAssertTrue(lines.isEmpty)
    }

    func test_cachesPreviousResult() async {
        var callCount = 0
        struct CountingSource: LyricsSource {
            let onCall: () -> Void
            func fetchSyncedLyrics(for track: Track) async -> String? {
                onCall()
                return "[00:01.00] Cached"
            }
        }
        let engine = LyricsEngine(primary: CountingSource { callCount += 1 }, fallback: MockSource(result: nil))
        _ = await engine.fetch(for: track)
        _ = await engine.fetch(for: track)
        XCTAssertEqual(callCount, 1)
    }

    func test_fetchesAgainForDifferentTrack() async {
        var callCount = 0
        struct CountingSource: LyricsSource {
            let onCall: () -> Void
            func fetchSyncedLyrics(for track: Track) async -> String? {
                onCall()
                return "[00:01.00] Line"
            }
        }
        let engine = LyricsEngine(primary: CountingSource { callCount += 1 }, fallback: MockSource(result: nil))
        _ = await engine.fetch(for: Track(title: "A", artist: "B", album: "C"))
        _ = await engine.fetch(for: Track(title: "X", artist: "Y", album: "Z"))
        XCTAssertEqual(callCount, 2)
    }
}
