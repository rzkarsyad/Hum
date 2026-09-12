import XCTest
@testable import Hum

@MainActor
final class PlaybackTickTests: XCTestCase {

    func test_displayTickIsOffUntilSomethingNeedsIt() {
        let observer = MusicObserver()
        XCTAssertFalse(observer.isDisplayUpdating)
    }

    func test_displayTickFollowsVisibility() {
        let observer = MusicObserver()

        observer.setDisplayUpdatesEnabled(true)
        XCTAssertTrue(observer.isDisplayUpdating)

        observer.setDisplayUpdatesEnabled(false)
        XCTAssertFalse(observer.isDisplayUpdating)
    }

    func test_enablingTwiceKeepsASingleTick() {
        let observer = MusicObserver()
        observer.setDisplayUpdatesEnabled(true)
        let first = observer.isDisplayUpdating
        observer.setDisplayUpdatesEnabled(true)

        XCTAssertTrue(first)
        XCTAssertTrue(observer.isDisplayUpdating)

        // One disable is enough to stop it, which would not hold if the second
        // enable had scheduled a second timer.
        observer.setDisplayUpdatesEnabled(false)
        XCTAssertFalse(observer.isDisplayUpdating)
    }

    func test_stopTearsDownTheDisplayTick() {
        let observer = MusicObserver()
        observer.setDisplayUpdatesEnabled(true)
        observer.stop()
        XCTAssertFalse(observer.isDisplayUpdating)
    }

    /// The clock is what the instrumental dots animate from; it must not be the
    /// observer itself, or its display-rate tick reaches the whole window.
    func test_clockCarriesThePosition() {
        let clock = PlaybackClock()
        XCTAssertEqual(clock.position, 0)
        clock.update(42)
        XCTAssertEqual(clock.position, 42)
    }
}
