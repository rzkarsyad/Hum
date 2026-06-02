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

    // MARK: buildItems

    private func line(_ t: Double, _ text: String = "x") -> LyricLine {
        LyricLine(timestamp: t, text: text)
    }

    func test_buildItems_empty() {
        XCTAssertTrue(buildItems(from: []).isEmpty)
    }

    func test_buildItems_singleLine_noTrailingItem() {
        let items = buildItems(from: [line(10)])
        XCTAssertEqual(items, [.lyric(line(10))])
    }

    func test_buildItems_insertsIntroWhenFirstLineAfterThreshold() {
        // first line at 6s (>= 5) -> intro instrumental 0..6
        let items = buildItems(from: [line(6), line(8)])
        XCTAssertEqual(items.first, .instrumental(start: 0, end: 6))
    }

    func test_buildItems_noIntroWhenFirstLineEarly() {
        let items = buildItems(from: [line(2), line(4)])
        XCTAssertEqual(items.first, .lyric(line(2)))
    }

    func test_buildItems_insertsGapWhenLongEnough() {
        // line "x" (1 char) -> naturalDuration clamps to MIN_LINE 1.2
        // lineEnd = 0 + 1.2 = 1.2 ; next at 10 -> gap 8.8 >= 5 -> instrumental 1.2..10
        let items = buildItems(from: [line(0), line(10)])
        XCTAssertEqual(items, [.lyric(line(0)), .instrumental(start: 1.2, end: 10), .lyric(line(10))])
    }

    func test_buildItems_noGapWhenShort() {
        // lineEnd = 1.2 ; next at 4 -> remaining 2.8 < 5 -> no instrumental
        let items = buildItems(from: [line(0), line(4)])
        XCTAssertEqual(items, [.lyric(line(0)), .lyric(line(4))])
    }
}
