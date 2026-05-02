import XCTest
@testable import Hum

final class LRCParserTests: XCTestCase {

    func test_parsesStandardTimestamps() {
        let lrc = "[00:12.34] Hello world\n[00:15.67] Second line"
        let lines = LRCParser.parse(lrc)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].timestamp, 12.34, accuracy: 0.001)
        XCTAssertEqual(lines[0].text, "Hello world")
        XCTAssertEqual(lines[1].timestamp, 15.67, accuracy: 0.001)
    }

    func test_parsesMillisecondTimestamps() {
        let lrc = "[01:23.456] Three digit fraction"
        let lines = LRCParser.parse(lrc)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].timestamp, 83.456, accuracy: 0.001)
    }

    func test_skipsMetadataLines() {
        let lrc = "[ti:Song Title]\n[ar:Artist]\n[00:01.00] Actual lyric"
        let lines = LRCParser.parse(lrc)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].text, "Actual lyric")
    }

    func test_skipsEmptyTextLines() {
        let lrc = "[00:01.00] \n[00:02.00] Real line"
        let lines = LRCParser.parse(lrc)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].text, "Real line")
    }

    func test_sortsLinesByTimestamp() {
        let lrc = "[00:15.00] Second\n[00:05.00] First"
        let lines = LRCParser.parse(lrc)
        XCTAssertEqual(lines[0].text, "First")
        XCTAssertEqual(lines[1].text, "Second")
    }

    func test_returnsEmptyForEmptyInput() {
        XCTAssertTrue(LRCParser.parse("").isEmpty)
    }

    func test_parsesLargeMinutes() {
        let lrc = "[123:45.67] Long track line"
        let lines = LRCParser.parse(lrc)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].timestamp, 123 * 60 + 45.67, accuracy: 0.001)
    }

    func test_parsesWindowsLineEndings() {
        let lrc = "[00:01.00] First\r\n[00:02.00] Second"
        let lines = LRCParser.parse(lrc)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].text, "First")
        XCTAssertEqual(lines[1].text, "Second")
    }
}
