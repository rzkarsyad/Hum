import XCTest
@testable import Hum

final class LyricsDiskCacheTests: XCTestCase {

    private func tempCache() -> LyricsDiskCache {
        LyricsDiskCache(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("HumLyricsCacheTest-\(UUID().uuidString)"))
    }

    func test_cacheKey_roundsDuration() {
        let a = lyricsCacheKey(for: Track(title: "Song", artist: "Artist", album: "Album", duration: 180))
        let b = lyricsCacheKey(for: Track(title: "Song", artist: "Artist", album: "Album", duration: 180.4))
        XCTAssertEqual(a, b)
    }

    func test_cacheKey_differsByField() {
        let base = lyricsCacheKey(for: Track(title: "Song", artist: "Artist", album: "Album", duration: 180))
        XCTAssertNotEqual(base, lyricsCacheKey(for: Track(title: "Other", artist: "Artist", album: "Album", duration: 180)))
        XCTAssertNotEqual(base, lyricsCacheKey(for: Track(title: "Song", artist: "Diff", album: "Album", duration: 180)))
    }

    func test_saveThenLoadRoundTrips() {
        let cache = tempCache()
        let lines = [LyricLine(timestamp: 1, text: "Hello"), LyricLine(timestamp: 2, text: "World")]
        cache.save(lines, forKey: "k")
        XCTAssertEqual(cache.load(forKey: "k"), lines)
    }

    func test_loadMissingReturnsNil() {
        XCTAssertNil(tempCache().load(forKey: "nope"))
    }

    func test_saveEmptyDoesNotPersist() {
        let cache = tempCache()
        cache.save([], forKey: "k")
        XCTAssertNil(cache.load(forKey: "k"))
    }
}
