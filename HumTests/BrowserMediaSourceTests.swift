import XCTest
@testable import Hum

final class BrowserMediaSourceTests: XCTestCase {

    // MARK: - isBrowserBundleID

    func test_isBrowserBundleID_knownBrowsers() {
        XCTAssertTrue(isBrowserBundleID("com.google.Chrome"))
        XCTAssertTrue(isBrowserBundleID("com.apple.Safari"))
        XCTAssertTrue(isBrowserBundleID("company.thebrowser.Browser"))
        XCTAssertTrue(isBrowserBundleID("com.brave.Browser"))
        XCTAssertTrue(isBrowserBundleID("com.microsoft.edgemac"))
    }

    func test_isBrowserBundleID_nonBrowsers() {
        XCTAssertFalse(isBrowserBundleID("com.apple.Music"))
        XCTAssertFalse(isBrowserBundleID("com.spotify.client"))
        XCTAssertFalse(isBrowserBundleID(""))
        XCTAssertFalse(isBrowserBundleID("com.example.random"))
    }

    // MARK: - parseBrowserNowPlaying

    func test_parse_browserPlaying() {
        let line = #"{"bundleIdentifier":"com.google.Chrome","playing":true,"title":"Blinding Lights","artist":"The Weeknd","album":"After Hours","duration":200.0,"elapsedTime":42.5,"playbackRate":1.0}"#
        guard case let .browser(s) = parseBrowserNowPlaying(line) else { return XCTFail("expected .browser") }
        XCTAssertEqual(s.bundleID, "com.google.Chrome")
        XCTAssertEqual(s.title, "Blinding Lights")
        XCTAssertEqual(s.artist, "The Weeknd")
        XCTAssertEqual(s.album, "After Hours")
        XCTAssertEqual(s.duration ?? 0, 200.0, accuracy: 0.001)
        XCTAssertEqual(s.elapsedTime, 42.5, accuracy: 0.001)
        XCTAssertTrue(s.isPlaying)
    }

    func test_parse_browserPaused() {
        let line = #"{"bundleIdentifier":"com.apple.Safari","playing":false,"title":"Some Song"}"#
        guard case let .browser(s) = parseBrowserNowPlaying(line) else { return XCTFail("expected .browser") }
        XCTAssertFalse(s.isPlaying)
        XCTAssertEqual(s.artist, "")
        XCTAssertNil(s.duration)
    }

    func test_parse_nonBrowserIsOther() {
        let line = #"{"bundleIdentifier":"com.apple.Music","playing":true,"title":"X"}"#
        XCTAssertEqual(parseBrowserNowPlaying(line), .other)
    }

    func test_parse_matchesViaParentBundleID() {
        let line = #"{"bundleIdentifier":"com.google.Chrome.helper","parentApplicationBundleIdentifier":"com.google.Chrome","playing":true,"title":"Y"}"#
        guard case let .browser(s) = parseBrowserNowPlaying(line) else { return XCTFail("expected .browser") }
        XCTAssertEqual(s.bundleID, "com.google.Chrome")
    }

    func test_parse_artworkBase64Decoded() {
        // base64 of "hi" = "aGk="
        let line = #"{"bundleIdentifier":"com.google.Chrome","playing":true,"title":"T","artworkData":"aGk="}"#
        guard case let .browser(s) = parseBrowserNowPlaying(line) else { return XCTFail("expected .browser") }
        XCTAssertEqual(s.artworkData, Data("hi".utf8))
    }

    func test_parse_malformedIsIgnore() {
        XCTAssertEqual(parseBrowserNowPlaying("not json"), .ignore)
        XCTAssertEqual(parseBrowserNowPlaying(""), .ignore)
    }

    func test_parse_browserWithoutTitleIsOther() {
        let line = #"{"bundleIdentifier":"com.google.Chrome","playing":true}"#
        XCTAssertEqual(parseBrowserNowPlaying(line), .other)
    }

    // MARK: - stream envelope ({"type":"data","diff":...,"payload":{...}})

    func test_parse_streamEnvelopeUnwrapped() {
        // Real-world shape: YouTube Music in Safari reports via WebKit.GPU with a
        // Safari parent, nested inside the stream envelope.
        let line = #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.apple.WebKit.GPU","parentApplicationBundleIdentifier":"com.apple.Safari","playing":true,"title":"Curious","artist":"AND2BLE","duration":180.0,"elapsedTime":5.0,"playbackRate":1.0}}"#
        guard case let .browser(s) = parseBrowserNowPlaying(line) else {
            return XCTFail("expected .browser from stream envelope")
        }
        XCTAssertEqual(s.bundleID, "com.apple.Safari")  // resolved via parent
        XCTAssertEqual(s.title, "Curious")
        XCTAssertEqual(s.artist, "AND2BLE")
        XCTAssertTrue(s.isPlaying)
    }

    func test_parse_streamEmptyPayloadIsOther() {
        XCTAssertEqual(parseBrowserNowPlaying(#"{"type":"data","diff":false,"payload":{}}"#), .other)
    }

    func test_parse_streamNonBrowserPayloadIsOther() {
        let line = #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.apple.Music","playing":true,"title":"X"}}"#
        XCTAssertEqual(parseBrowserNowPlaying(line), .other)
    }

    // MARK: - position anchoring (the "racing lyrics" fix)

    func test_parse_parsesMediaTimestamp() {
        let line = #"{"type":"data","diff":false,"payload":{"bundleIdentifier":"com.google.Chrome","playing":true,"title":"T","elapsedTime":13.207,"timestamp":"2026-06-06T19:24:49Z"}}"#
        guard case let .browser(s) = parseBrowserNowPlaying(line) else { return XCTFail("expected .browser") }
        XCTAssertEqual(s.timestamp, ISO8601DateFormatter().date(from: "2026-06-06T19:24:49Z"))
        XCTAssertEqual(s.elapsedTime, 13.207, accuracy: 0.001)
    }

    func test_livePosition_extrapolatesFromAnchor() {
        // Snapshot sampled at 13.207s, 88s ago, playing 1x → real position ~101.2s,
        // NOT the stale 13.2s. This is the regression that caused racing lyrics.
        let anchor = ISO8601DateFormatter().date(from: "2026-06-06T19:24:49Z")!
        let now = anchor.addingTimeInterval(88)
        XCTAssertEqual(livePosition(elapsedTime: 13.207, anchor: anchor, rate: 1, now: now),
                       101.207, accuracy: 0.01)
    }

    func test_livePosition_rateZeroTreatedAsRealtime() {
        let anchor = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(livePosition(elapsedTime: 5, anchor: anchor, rate: 0, now: anchor.addingTimeInterval(10)),
                       15, accuracy: 0.001)
    }
}
