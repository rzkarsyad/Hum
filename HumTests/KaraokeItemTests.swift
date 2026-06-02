import XCTest
@testable import Hum

final class KaraokeItemTests: XCTestCase {

    // MARK: naturalDuration

    func test_naturalDuration_clampsToMin() {
        // 2 chars * 0.13 = 0.26 -> clamps up to MIN_LINE (1.2)
        XCTAssertEqual(naturalDuration(LyricLine(timestamp: 0, text: "hi")), 1.2, accuracy: 0.0001)
    }

    func test_naturalDuration_clampsToMax() {
        let long = String(repeating: "a", count: 100) // 100 * 0.13 = 13 -> clamps to MAX_LINE (5.0)
        XCTAssertEqual(naturalDuration(LyricLine(timestamp: 0, text: long)), 5.0, accuracy: 0.0001)
    }

    func test_naturalDuration_scalesInBetween() {
        let text = String(repeating: "a", count: 20) // 20 * 0.13 = 2.6
        XCTAssertEqual(naturalDuration(LyricLine(timestamp: 0, text: text)), 2.6, accuracy: 0.0001)
    }

    // MARK: dotFill

    func test_dotFill_allEmptyAtZero() {
        XCTAssertEqual(dotFill(0, progress: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(dotFill(1, progress: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(dotFill(2, progress: 0), 0, accuracy: 0.0001)
    }

    func test_dotFill_firstDotMidway() {
        // progress 1/6 -> dot0 = 0.5, others 0
        XCTAssertEqual(dotFill(0, progress: 1.0 / 6.0), 0.5, accuracy: 0.0001)
        XCTAssertEqual(dotFill(1, progress: 1.0 / 6.0), 0, accuracy: 0.0001)
    }

    func test_dotFill_firstDotFullAtThird() {
        XCTAssertEqual(dotFill(0, progress: 1.0 / 3.0), 1, accuracy: 0.0001)
        XCTAssertEqual(dotFill(1, progress: 1.0 / 3.0), 0, accuracy: 0.0001)
    }

    func test_dotFill_allFullAtOne() {
        XCTAssertEqual(dotFill(0, progress: 1), 1, accuracy: 0.0001)
        XCTAssertEqual(dotFill(1, progress: 1), 1, accuracy: 0.0001)
        XCTAssertEqual(dotFill(2, progress: 1), 1, accuracy: 0.0001)
    }
}
