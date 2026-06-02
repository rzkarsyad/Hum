import Foundation

// Tunable timing constants (adjust after manual testing)
let SEC_PER_CHAR: TimeInterval = 0.13
let MIN_LINE: TimeInterval = 1.2
let MAX_LINE: TimeInterval = 5.0
let GAP_THRESHOLD: TimeInterval = 5.0

enum KaraokeItem: Equatable {
    case lyric(LyricLine)
    case instrumental(start: TimeInterval, end: TimeInterval)

    var start: TimeInterval {
        switch self {
        case .lyric(let line): return line.timestamp
        case .instrumental(let start, _): return start
        }
    }
}

/// Estimated natural sung duration of a line, used to cap the appearance
/// animation and to find where an instrumental gap begins.
func naturalDuration(_ line: LyricLine) -> TimeInterval {
    let raw = Double(line.text.count) * SEC_PER_CHAR
    return min(max(raw, MIN_LINE), MAX_LINE)
}

/// Fill amount (0...1) of dot `i` (0..<3) for a gap progress (0...1).
/// dot 0 fills over 0–1/3, dot 1 over 1/3–2/3, dot 2 over 2/3–1.
func dotFill(_ i: Int, progress: Double) -> Double {
    min(max(progress * 3 - Double(i), 0), 1)
}

/// Builds the merged display list, inserting `.instrumental` items for the intro
/// and for any inter-line gap that, after the line's natural duration, still leaves
/// at least `GAP_THRESHOLD` seconds of music.
func buildItems(from lines: [LyricLine]) -> [KaraokeItem] {
    guard let first = lines.first else { return [] }

    var items: [KaraokeItem] = []

    if lines.count > 1 && first.timestamp >= GAP_THRESHOLD {
        items.append(.instrumental(start: 0, end: first.timestamp))
    }

    for index in lines.indices {
        let line = lines[index]
        items.append(.lyric(line))

        guard index + 1 < lines.count else { continue }
        let nextStart = lines[index + 1].timestamp
        let lineEnd = line.timestamp + naturalDuration(line)
        if nextStart - lineEnd >= GAP_THRESHOLD {
            items.append(.instrumental(start: lineEnd, end: nextStart))
        }
    }

    return items
}
