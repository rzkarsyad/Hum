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
}
