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
}
