import XCTest
@testable import Hum

final class MusicObserverTests: XCTestCase {

    func test_isSeekReturnsTrueWhenDiffExceedsThreshold() {
        XCTAssertTrue(isSeek(reported: 10.0, interpolated: 12.0))
    }

    func test_isSeekReturnsFalseWhenDiffWithinThreshold() {
        XCTAssertFalse(isSeek(reported: 10.0, interpolated: 10.3))
    }

    func test_isSeekReturnsFalseAtExactThreshold() {
        XCTAssertFalse(isSeek(reported: 10.0, interpolated: 11.5))
    }

    func test_isSeekHandlesBackwardSeek() {
        XCTAssertTrue(isSeek(reported: 5.0, interpolated: 10.0))
    }

    // MARK: - parsePollResult

    func test_parsePlayingAppleMusic() {
        let raw = "playing\tmusic\tBohemian Rhapsody\tQueen\tA Night at the Opera\t12.5\t354.0"
        guard case let .playing(r) = parsePollResult(raw) else {
            return XCTFail("expected .playing")
        }
        XCTAssertEqual(r.source, .appleMusic)
        XCTAssertEqual(r.track.title, "Bohemian Rhapsody")
        XCTAssertEqual(r.track.artist, "Queen")
        XCTAssertEqual(r.track.album, "A Night at the Opera")
        XCTAssertEqual(r.track.duration ?? 0, 354.0, accuracy: 0.001)
        XCTAssertEqual(r.position, 12.5, accuracy: 0.001)
    }

    func test_parsePlayingSpotify() {
        let raw = "playing\tspotify\tStarboy\tThe Weeknd\tStarboy\t30.0\t230.4"
        guard case let .playing(r) = parsePollResult(raw) else {
            return XCTFail("expected .playing")
        }
        XCTAssertEqual(r.source, .spotify)
        XCTAssertEqual(r.track.title, "Starboy")
        XCTAssertEqual(r.track.artist, "The Weeknd")
        XCTAssertEqual(r.position, 30.0, accuracy: 0.001)
        XCTAssertEqual(r.track.duration ?? 0, 230.4, accuracy: 0.001)
    }

    func test_parseHandlesCommaDecimalSeparator() {
        let raw = "playing\tmusic\tSong\tArtist\tAlbum\t12,5\t200,0"
        guard case let .playing(r) = parsePollResult(raw) else {
            return XCTFail("expected .playing")
        }
        XCTAssertEqual(r.position, 12.5, accuracy: 0.001)
        XCTAssertEqual(r.track.duration ?? 0, 200.0, accuracy: 0.001)
    }

    func test_parsePaused() {
        XCTAssertEqual(parsePollResult("paused"), .paused)
    }

    func test_parseStoppedAndNotRunning() {
        XCTAssertEqual(parsePollResult("stopped"), .stopped)
        XCTAssertEqual(parsePollResult("not_running"), .stopped)
    }

    func test_parseUnknownSourceFallsBackToStopped() {
        XCTAssertEqual(parsePollResult("playing\tdeezer\tt\ta\talb\t1\t2"), .stopped)
    }

    func test_parseMalformedFallsBackToStopped() {
        XCTAssertEqual(parsePollResult("playing\tmusic\ttoo\tfew"), .stopped)
    }
}
