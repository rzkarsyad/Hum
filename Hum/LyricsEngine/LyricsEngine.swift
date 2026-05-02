import Foundation

final class LyricsEngine {
    private let primary: any LyricsSource
    private let fallback: any LyricsSource
    private var cache: [Track: [LyricLine]] = [:]

    init(primary: any LyricsSource = MusicKitSource(), fallback: any LyricsSource = LRCLIBSource()) {
        self.primary = primary
        self.fallback = fallback
    }

    func fetch(for track: Track) async -> [LyricLine] {
        if let cached = cache[track] { return cached }

        let primaryResult = await primary.fetchSyncedLyrics(for: track)
        let lrc: String?
        if let r = primaryResult {
            lrc = r
        } else {
            lrc = await fallback.fetchSyncedLyrics(for: track)
        }

        let lines = lrc.map { LRCParser.parse($0) } ?? []
        cache[track] = lines
        return lines
    }
}
