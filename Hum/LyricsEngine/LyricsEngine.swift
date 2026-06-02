import Foundation

enum LyricsFetchResult {
    case found([LyricLine])
    case notFound
    case networkError
}

final class LyricsEngine {
    private let primary: any LyricsSource
    private let fallback: any LyricsSource
    private var cache: [Track: [LyricLine]] = [:]

    init(primary: any LyricsSource = MusicKitSource(), fallback: any LyricsSource = LRCLIBSource()) {
        self.primary = primary
        self.fallback = fallback
    }

    func fetch(for track: Track, mediaItemLyrics: String? = nil) async -> LyricsFetchResult {
        if let cached = cache[track] {
            return cached.isEmpty ? .notFound : .found(cached)
        }

        let lrc: String?
        var hadNetworkError = false

        if let fromDevice = mediaItemLyrics {
            lrc = fromDevice
        } else {
            let primaryResult = await primary.fetchSyncedLyrics(for: track)
            if let r = primaryResult {
                lrc = r
            } else {
                let fallbackResult = await fallback.fetchSyncedLyricsWithError(for: track)
                switch fallbackResult {
                case .success(let s): lrc = s
                case .failure: lrc = nil; hadNetworkError = true
                }
            }
        }

        let lines = lrc.map { LRCParser.parse($0) } ?? []
        cache[track] = lines

        if !lines.isEmpty { return .found(lines) }
        return hadNetworkError ? .networkError : .notFound
    }
}
