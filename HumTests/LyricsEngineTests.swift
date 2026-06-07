import XCTest
@testable import Hum

final class LyricsEngineTests: XCTestCase {

    private struct MockSource: LyricsSource {
        let result: String?
        func fetchSyncedLyrics(for track: Track) async -> String? { result }
    }

    private let track = Track(title: "Test", artist: "Artist", album: "Album")
    private let sampleLRC = "[00:01.00] Hello\n[00:02.00] World"

    /// Isolated on-disk cache per use so tests never touch the real cache dir or
    /// each other's state.
    private func tempCache() -> LyricsDiskCache {
        LyricsDiskCache(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("HumLE-\(UUID().uuidString)"))
    }

    func test_returnsParsedLinesOnSuccess() async {
        let engine = LyricsEngine(primary: MockSource(result: sampleLRC), fallback: MockSource(result: nil), diskCache: tempCache())
        let result = await engine.fetch(for: track)
        guard case .found(let lines) = result else { return XCTFail("Expected .found") }
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].text, "Hello")
    }

    func test_fallsBackWhenPrimaryReturnsNil() async {
        let engine = LyricsEngine(primary: MockSource(result: nil), fallback: MockSource(result: sampleLRC), diskCache: tempCache())
        let result = await engine.fetch(for: track)
        guard case .found(let lines) = result else { return XCTFail("Expected .found") }
        XCTAssertEqual(lines.count, 2)
    }

    func test_returnsEmptyWhenBothSourcesFail() async {
        let engine = LyricsEngine(primary: MockSource(result: nil), fallback: MockSource(result: nil), diskCache: tempCache())
        let result = await engine.fetch(for: track)
        if case .found(let lines) = result {
            XCTFail("Expected notFound or networkError, got .found(\(lines))")
        }
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
        let engine = LyricsEngine(primary: CountingSource { callCount += 1 }, fallback: MockSource(result: nil), diskCache: tempCache())
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
        let engine = LyricsEngine(primary: CountingSource { callCount += 1 }, fallback: MockSource(result: nil), diskCache: tempCache())
        _ = await engine.fetch(for: Track(title: "A", artist: "B", album: "C"))
        _ = await engine.fetch(for: Track(title: "X", artist: "Y", album: "Z"))
        XCTAssertEqual(callCount, 2)
    }

    func test_usesMediaItemLyricsWhenProvided() async {
        let lrc = "[00:01.00] From device\n[00:02.00] Library"
        let engine = LyricsEngine(primary: MockSource(result: nil), fallback: MockSource(result: nil), diskCache: tempCache())
        let result = await engine.fetch(for: track, mediaItemLyrics: lrc)
        guard case .found(let lines) = result else { return XCTFail("Expected .found") }
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].text, "From device")
    }

    func test_fallsBackToSourcesWhenMediaItemLyricsNil() async {
        let engine = LyricsEngine(primary: MockSource(result: nil), fallback: MockSource(result: sampleLRC), diskCache: tempCache())
        let result = await engine.fetch(for: track, mediaItemLyrics: nil)
        guard case .found(let lines) = result else { return XCTFail("Expected .found") }
        XCTAssertEqual(lines.count, 2)
    }

    func test_mediaItemLyricsTakesPrecedenceOverPrimary() async {
        let fromDevice = "[00:01.00] Device line"
        let fromNetwork = "[00:01.00] Network line"
        let engine = LyricsEngine(primary: MockSource(result: fromNetwork), fallback: MockSource(result: nil), diskCache: tempCache())
        let result = await engine.fetch(for: track, mediaItemLyrics: fromDevice)
        guard case .found(let lines) = result else { return XCTFail("Expected .found") }
        XCTAssertEqual(lines[0].text, "Device line")
    }

    func test_diskCachePersistsAcrossEngineInstances() async {
        let cache = tempCache()
        let engine1 = LyricsEngine(primary: MockSource(result: sampleLRC), fallback: MockSource(result: nil), diskCache: cache)
        _ = await engine1.fetch(for: track)

        // A fresh engine with sources that return nothing must still find the
        // lyrics on disk (simulating a relaunch).
        let engine2 = LyricsEngine(primary: MockSource(result: nil), fallback: MockSource(result: nil), diskCache: cache)
        let result = await engine2.fetch(for: track)
        guard case .found(let lines) = result else { return XCTFail("Expected .found from disk") }
        XCTAssertEqual(lines.count, 2)
    }

    func test_notFoundIsNotPersistedToDisk() async {
        let cache = tempCache()
        let engine = LyricsEngine(primary: MockSource(result: nil), fallback: MockSource(result: nil), diskCache: cache)
        _ = await engine.fetch(for: track)  // notFound
        XCTAssertNil(cache.load(forKey: lyricsCacheKey(for: track)))
    }
}

final class MPMediaItemLyricsSourceTests: XCTestCase {
    private let source = MPMediaItemLyricsSource()

    func test_returnsNilForEmptyString() {
        XCTAssertNil(source.parseLRC(""))
    }

    func test_returnsNilForPlainText() {
        XCTAssertNil(source.parseLRC("Verse 1\nSome lyrics here\nNo timestamps"))
    }

    func test_returnsStringWhenLRCFormatDetected() {
        let lrc = "[00:01.00] Hello\n[00:02.50] World"
        XCTAssertEqual(source.parseLRC(lrc), lrc)
    }

    func test_detectsLRCWithThreeDigitFraction() {
        let lrc = "[01:23.456] Line with milliseconds"
        XCTAssertNotNil(source.parseLRC(lrc))
    }

    func test_returnsNotNilWhenTimestampAtLineStart() {
        let text = "Some text\n[00:01.00] timestamp at start of second line"
        XCTAssertNotNil(source.parseLRC(text))
    }
}
