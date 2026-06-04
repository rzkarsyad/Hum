protocol LyricsSource {
    func fetchSyncedLyrics(for track: Track) async -> String?
    /// Error-aware variant used by the engine's fallback path so it can distinguish
    /// "no lyrics" from "network failure". Defaults to wrapping `fetchSyncedLyrics`
    /// in `.success`; `LRCLIBSource` overrides it to surface real request errors.
    func fetchSyncedLyricsWithError(for track: Track) async -> Result<String?, Error>
}

extension LyricsSource {
    func fetchSyncedLyricsWithError(for track: Track) async -> Result<String?, Error> {
        .success(await fetchSyncedLyrics(for: track))
    }
}
