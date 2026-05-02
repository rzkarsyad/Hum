import XCTest
@testable import Hum

final class WordTokenTests: XCTestCase {

    func test_singleWord_usesLineTimestampPlusBuffer() {
        // duration=2.0, start_offset=0.2 → word[0] = 10.0 + 0.2 = 10.2
        let line = LyricLine(timestamp: 10.0, text: "Hello")
        let tokens = wordTokens(for: line, nextTimestamp: 12.0)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].text, "Hello")
        XCTAssertEqual(tokens[0].timestamp, 10.2, accuracy: 0.001)
    }

    func test_twoEqualWords_charWeightedWithBuffer() {
        // duration=2.0, start_offset=0.2, effective=1.6, "Hello"=5 "world"=5, total=10
        // word[0]: 10.0 + 0.2 + (0/10)*1.6 = 10.2
        // word[1]: 10.0 + 0.2 + (5/10)*1.6 = 11.0
        let line = LyricLine(timestamp: 10.0, text: "Hello world")
        let tokens = wordTokens(for: line, nextTimestamp: 12.0)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].timestamp, 10.2, accuracy: 0.001)
        XCTAssertEqual(tokens[1].timestamp, 11.0, accuracy: 0.001)
    }

    func test_noNextTimestamp_uses5sFallback() {
        // duration=5.0, start_offset=0.5, effective=4.0, "Hello"=5 "world"=5, total=10
        // word[0]: 10.0 + 0.5 + 0 = 10.5
        // word[1]: 10.0 + 0.5 + (5/10)*4.0 = 12.5
        let line = LyricLine(timestamp: 10.0, text: "Hello world")
        let tokens = wordTokens(for: line, nextTimestamp: nil)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].timestamp, 10.5, accuracy: 0.001)
        XCTAssertEqual(tokens[1].timestamp, 12.5, accuracy: 0.001)
    }

    func test_timestampsAreMonotonicallyIncreasing() {
        let line = LyricLine(timestamp: 0.0, text: "one two three four")
        let tokens = wordTokens(for: line, nextTimestamp: 4.0)
        XCTAssertEqual(tokens.count, 4)
        for i in 1..<tokens.count {
            XCTAssertGreaterThan(tokens[i].timestamp, tokens[i - 1].timestamp)
        }
    }

    func test_emptyText_returnsEmpty() {
        let line = LyricLine(timestamp: 10.0, text: "")
        let tokens = wordTokens(for: line, nextTimestamp: 12.0)
        XCTAssertTrue(tokens.isEmpty)
    }

    func test_extraSpaces_filtered() {
        let line = LyricLine(timestamp: 10.0, text: "hello  world")
        let tokens = wordTokens(for: line, nextTimestamp: 12.0)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].text, "hello")
        XCTAssertEqual(tokens[1].text, "world")
    }

    func test_longerWordGetsMoreTime() {
        // "hi"(2) + "world"(5) = 7 chars. duration=7.0 → start_offset=0.7, effective=5.6
        // word[0] ("hi"):    0.0 + 0.7 + (0/7)*5.6 = 0.7
        // word[1] ("world"): 0.0 + 0.7 + (2/7)*5.6 = 0.7 + 1.6 = 2.3
        // Even distribution would put word[1] at 3.5 — char-weight is earlier because "hi" is short
        let line = LyricLine(timestamp: 0.0, text: "hi world")
        let tokens = wordTokens(for: line, nextTimestamp: 7.0)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].timestamp, 0.7, accuracy: 0.001)
        XCTAssertEqual(tokens[1].timestamp, 2.3, accuracy: 0.001)
        XCTAssertLessThan(tokens[1].timestamp, 3.5)
    }
}
