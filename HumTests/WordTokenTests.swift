import XCTest
@testable import Hum

final class WordTokenTests: XCTestCase {

    func test_singleWord_usesLineTimestamp() {
        let line = LyricLine(timestamp: 10.0, text: "Hello")
        let tokens = wordTokens(for: line, nextTimestamp: 12.0)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].text, "Hello")
        XCTAssertEqual(tokens[0].timestamp, 10.0, accuracy: 0.001)
    }

    func test_twoWords_splitsDurationEvenly() {
        let line = LyricLine(timestamp: 10.0, text: "Hello world")
        let tokens = wordTokens(for: line, nextTimestamp: 12.0)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].timestamp, 10.0, accuracy: 0.001)
        XCTAssertEqual(tokens[1].timestamp, 11.0, accuracy: 0.001)
    }

    func test_noNextTimestamp_uses5sFallback() {
        let line = LyricLine(timestamp: 10.0, text: "Hello world")
        let tokens = wordTokens(for: line, nextTimestamp: nil)
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].timestamp, 10.0, accuracy: 0.001)
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
}
