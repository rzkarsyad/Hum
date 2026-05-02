// MusicKit's public API exposes only plain-text Song.lyrics, not timestamped lyrics.
// Karaoke sync requires timestamps, so this always returns nil.
// Preserved so the fallback chain is ready if Apple opens the synced lyrics API.
struct MusicKitSource: LyricsSource {
    func fetchSyncedLyrics(for track: Track) async -> String? { nil }
}
