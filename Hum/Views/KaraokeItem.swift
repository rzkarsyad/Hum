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
