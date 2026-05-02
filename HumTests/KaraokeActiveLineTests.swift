import XCTest
@testable import Hum

final class KaraokeActiveLineTests: XCTestCase {

    private func lines(_ timestamps: [Double]) -> [LyricLine] {
        timestamps.enumerated().map { LyricLine(timestamp: $0.element, text: "Line \($0.offset)") }
    }

    func test_returnsNilBeforeFirstLine() {
        XCTAssertNil(activeIndex(in: lines([5, 10, 15]), at: 3))
    }

    func test_returnsFirstLineAtExactTimestamp() {
        XCTAssertEqual(activeIndex(in: lines([5, 10, 15]), at: 5), 0)
    }

    func test_returnsLastLineBeforePosition() {
        XCTAssertEqual(activeIndex(in: lines([5, 10, 15]), at: 12), 1)
    }

    func test_returnsLastLineWhenPastAllLines() {
        XCTAssertEqual(activeIndex(in: lines([5, 10, 15]), at: 99), 2)
    }

    func test_returnsNilForEmptyLines() {
        XCTAssertNil(activeIndex(in: [], at: 10))
    }
}
