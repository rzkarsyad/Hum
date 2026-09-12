import Combine
import XCTest
@testable import Hum

@MainActor
final class LyricsStateTests: XCTestCase {

    // Close enough together that buildItems inserts no instrumental gaps, so
    // item indices line up with line indices and the assertions stay readable.
    private let lines = [
        LyricLine(timestamp: 1, text: "first"),
        LyricLine(timestamp: 4, text: "second"),
        LyricLine(timestamp: 7, text: "third"),
    ]

    // MARK: - Derived display list

    func test_itemsAreDerivedFromLines() {
        let state = LyricsState()
        XCTAssertTrue(state.items.isEmpty)

        state.lines = lines
        XCTAssertEqual(state.items, buildItems(from: lines))
    }

    func test_clearingLinesClearsItemsAndActiveItem() {
        let state = LyricsState()
        state.lines = lines
        state.updatePosition(5)
        XCTAssertNotNil(state.activeItem)

        state.lines = []
        XCTAssertTrue(state.items.isEmpty)
        XCTAssertNil(state.activeItem)
    }

    // MARK: - Active item

    func test_activeItemIsNilBeforeTheFirstLine() {
        let state = LyricsState()
        state.lines = lines
        state.updatePosition(0.5)
        XCTAssertNil(state.activeItem)
    }

    func test_activeItemFollowsPosition() {
        let state = LyricsState()
        state.lines = lines

        state.updatePosition(1)
        XCTAssertEqual(state.activeItem, 0)

        state.updatePosition(5)
        XCTAssertEqual(state.activeItem, 1)

        state.updatePosition(999)
        XCTAssertEqual(state.activeItem, state.items.count - 1)
    }

    func test_newLinesPickUpTheLastKnownPosition() {
        let state = LyricsState()
        state.updatePosition(5)
        state.lines = lines
        XCTAssertEqual(state.activeItem, 1)
    }

    // MARK: - Publishing

    /// The whole point of holding the active item here: feeding the position in
    /// at display rate must not republish while the same line is still being
    /// sung, or every observer of this object is invalidated once per frame.
    func test_positionUpdatesWithinOneLineDoNotRepublish() {
        let state = LyricsState()
        state.lines = lines
        state.updatePosition(4)

        var publishes = 0
        let token = state.objectWillChange.sink { _ in publishes += 1 }
        defer { token.cancel() }

        // A second of display-rate ticks, all inside the same line.
        for tick in 0..<60 {
            state.updatePosition(4 + Double(tick) / 60.0)
        }
        XCTAssertEqual(publishes, 0)
    }

    func test_crossingIntoTheNextLineRepublishesOnce() {
        let state = LyricsState()
        state.lines = lines
        state.updatePosition(4)

        var publishes = 0
        let token = state.objectWillChange.sink { _ in publishes += 1 }
        defer { token.cancel() }

        state.updatePosition(6.9)
        XCTAssertEqual(publishes, 0)
        state.updatePosition(7.0)
        XCTAssertEqual(publishes, 1)
        state.updatePosition(7.5)
        XCTAssertEqual(publishes, 1)
    }
}
