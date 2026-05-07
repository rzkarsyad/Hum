import Foundation

struct MPMediaItemLyricsSource {
    private static let lrcLineRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: #"^\[\d{1,3}:\d{2}\.\d{2,3}\]"#, options: .anchorsMatchLines)
    }()

    /// Reads raw lyrics from a media item's `lyrics` property string and returns it
    /// if it appears to be in LRC format, otherwise returns nil.
    func fetchSyncedLyricsFromRaw(_ rawLyrics: String?) -> String? {
        guard let raw = rawLyrics else { return nil }
        return parseLRC(raw)
    }

    func parseLRC(_ text: String) -> String? {
        guard !text.isEmpty else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard Self.lrcLineRegex.firstMatch(in: text, range: range) != nil else { return nil }
        return text
    }
}
