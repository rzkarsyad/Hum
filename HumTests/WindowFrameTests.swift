import XCTest
@testable import Hum

/// Restoring a saved window frame after the display layout changed.
///
/// Hum's panel is borderless, has no Dock icon and no window menu, so a frame
/// restored outside every attached screen cannot be dragged back — the app is
/// effectively gone until its preferences are deleted by hand.
final class WindowFrameTests: XCTestCase {

    private let laptop = CGRect(x: 0, y: 0, width: 1512, height: 900)
    private let external = CGRect(x: 1512, y: 0, width: 2560, height: 1440)
    private let fallback = CGRect(x: 596, y: 60, width: 320, height: 276)

    func test_frameFullyOnScreenIsUntouched() {
        let saved = CGRect(x: 400, y: 200, width: 320, height: 276)
        XCTAssertEqual(reachableWindowFrame(saved: saved, screens: [laptop], fallback: fallback), saved)
    }

    func test_frameOnASecondDisplayIsKeptWhileThatDisplayIsAttached() {
        let saved = CGRect(x: 2000, y: 300, width: 320, height: 276)
        XCTAssertEqual(reachableWindowFrame(saved: saved, screens: [laptop, external], fallback: fallback), saved)
    }

    // The bug this exists for.
    func test_frameOnAnUnpluggedDisplayIsBroughtBack() {
        let saved = CGRect(x: 2000, y: 300, width: 320, height: 276)
        let restored = reachableWindowFrame(saved: saved, screens: [laptop], fallback: fallback)
        XCTAssertNotEqual(restored, saved, "a frame on a detached display must not be restored as-is")
        XCTAssertTrue(laptop.contains(restored), "it must land fully on an attached screen")
    }

    func test_bringingAFrameBackKeepsItsSize() {
        let saved = CGRect(x: 5000, y: 4000, width: 420, height: 310)
        let restored = reachableWindowFrame(saved: saved, screens: [laptop], fallback: fallback)
        XCTAssertEqual(restored.size, saved.size)
    }

    func test_aSliverOnScreenIsNotEnoughToGrab() {
        // Only 10pt of the window overlaps the screen edge — not enough to drag.
        let saved = CGRect(x: laptop.maxX - 10, y: 300, width: 320, height: 276)
        let restored = reachableWindowFrame(saved: saved, screens: [laptop], fallback: fallback)
        XCTAssertTrue(laptop.contains(restored))
    }

    func test_enoughOfTheHeaderOnScreenIsLeftAlone() {
        // Deliberately hanging off the edge, but with a grabbable strip showing.
        let saved = CGRect(x: laptop.maxX - 200, y: 300, width: 320, height: 276)
        XCTAssertEqual(reachableWindowFrame(saved: saved, screens: [laptop], fallback: fallback), saved)
    }

    func test_frameBiggerThanTheScreenIsShrunkToFit() {
        let saved = CGRect(x: -500, y: -500, width: 4000, height: 3000)
        let restored = reachableWindowFrame(saved: saved, screens: [laptop], fallback: fallback)
        XCTAssertTrue(laptop.contains(restored))
        XCTAssertLessThanOrEqual(restored.width, laptop.width)
        XCTAssertLessThanOrEqual(restored.height, laptop.height)
    }

    func test_unusableSavedFramesFallBack() {
        XCTAssertEqual(reachableWindowFrame(saved: .zero, screens: [laptop], fallback: fallback), fallback)
        XCTAssertEqual(reachableWindowFrame(saved: CGRect(x: 10, y: 10, width: 0, height: 276),
                                            screens: [laptop], fallback: fallback), fallback)
        XCTAssertEqual(reachableWindowFrame(saved: CGRect(x: CGFloat.nan, y: 10, width: 320, height: 276),
                                            screens: [laptop], fallback: fallback), fallback)
        XCTAssertEqual(reachableWindowFrame(saved: CGRect(x: CGFloat.infinity, y: 10, width: 320, height: 276),
                                            screens: [laptop], fallback: fallback), fallback)
    }

    func test_withNoScreensKnownTheSavedFrameIsLeftAlone() {
        // Nothing to validate against; moving the window would be a guess.
        let saved = CGRect(x: 2000, y: 300, width: 320, height: 276)
        XCTAssertEqual(reachableWindowFrame(saved: saved, screens: [], fallback: fallback), saved)
    }

    func test_windowIsBroughtBackToTheNearestScreen() {
        // Far off the right of the external display — it should return there,
        // not jump to the laptop on the other side.
        let saved = CGRect(x: 6000, y: 400, width: 320, height: 276)
        let restored = reachableWindowFrame(saved: saved, screens: [laptop, external], fallback: fallback)
        XCTAssertTrue(external.contains(restored), "expected it on the nearer screen, got \(restored)")
    }
}
