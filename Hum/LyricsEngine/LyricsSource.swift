protocol LyricsSource {
    func fetchSyncedLyrics(for track: Track) async -> String?
}
