import Foundation

struct LRCParser {
    private static let lineRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: #"^\[(\d{1,3}):(\d{2})\.(\d{2,3})\](.*)"#)
    }()

    static func parse(_ lrc: String) -> [LyricLine] {
        lrc.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .compactMap { parseLine($0) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private static func parseLine(_ line: String) -> LyricLine? {
        guard let match = lineRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges == 5 else { return nil }

        let minutes = Double(extract(line, match.range(at: 1))) ?? 0
        let seconds = Double(extract(line, match.range(at: 2))) ?? 0
        let fractionStr = extract(line, match.range(at: 3))
        let fraction = Double(fractionStr) ?? 0
        let divisor = fractionStr.count == 3 ? 1000.0 : 100.0
        let text = extract(line, match.range(at: 4)).trimmingCharacters(in: .whitespaces)

        guard !text.isEmpty else { return nil }

        return LyricLine(timestamp: minutes * 60 + seconds + fraction / divisor, text: text)
    }

    private static func extract(_ string: String, _ range: NSRange) -> String {
        guard let range = Range(range, in: string) else { return "" }
        return String(string[range])
    }
}
