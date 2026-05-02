import Foundation

struct WordToken {
    let text: String
    let timestamp: TimeInterval
}

func wordTokens(for line: LyricLine, nextTimestamp: TimeInterval?) -> [WordToken] {
    let words = line.text.components(separatedBy: " ").filter { !$0.isEmpty }
    guard !words.isEmpty else { return [] }

    let duration = nextTimestamp.map { max(0.1, $0 - line.timestamp) } ?? 5.0

    return words.enumerated().map { index, word in
        let t = line.timestamp + TimeInterval(index) / TimeInterval(words.count) * duration
        return WordToken(text: word, timestamp: t)
    }
}
