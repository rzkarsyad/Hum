import Foundation
import CryptoKit

/// Stable, launch-independent cache key for a track. Duration is rounded so tiny
/// differences (e.g. 180.0 vs 180.4) still hit the same entry.
func lyricsCacheKey(for track: Track) -> String {
    "\(track.title)\u{1}\(track.artist)\u{1}\(track.album)\u{1}\(Int((track.duration ?? 0).rounded()))"
}

/// Persists found lyrics to disk (one JSON file per track) so they survive
/// relaunches. Only non-empty lyrics are ever stored, so a transient miss is
/// never cached. File operations are atomic and key-scoped, so it is safe to use
/// from concurrent fetches.
struct LyricsDiskCache {
    private let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = base.appendingPathComponent("Hum/LyricsCache", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    func load(forKey key: String) -> [LyricLine]? {
        guard let data = try? Data(contentsOf: fileURL(forKey: key)),
              let lines = try? JSONDecoder().decode([LyricLine].self, from: data),
              !lines.isEmpty
        else { return nil }
        return lines
    }

    func save(_ lines: [LyricLine], forKey key: String) {
        guard !lines.isEmpty, let data = try? JSONEncoder().encode(lines) else { return }
        try? data.write(to: fileURL(forKey: key), options: .atomic)
    }

    private func fileURL(forKey key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name + ".json")
    }
}
