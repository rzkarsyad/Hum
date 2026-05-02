import Foundation

struct WordToken {
    let text: String
    let timestamp: TimeInterval
}

func wordTokens(for line: LyricLine, nextTimestamp: TimeInterval?) -> [WordToken] {
    let words = line.text.components(separatedBy: " ").filter { !$0.isEmpty }
    guard !words.isEmpty else { return [] }

    let duration = nextTimestamp.map { max(0.1, $0 - line.timestamp) } ?? 5.0
    let effectiveDuration = duration * 0.9
    let totalChars = words.reduce(0) { $0 + $1.count }
    guard totalChars > 0 else { return [] }

    var cumulative = 0
    return words.map { word in
        let t = line.timestamp + (Double(cumulative) / Double(totalChars)) * effectiveDuration
        cumulative += word.count
        return WordToken(text: word, timestamp: t)
    }
}
