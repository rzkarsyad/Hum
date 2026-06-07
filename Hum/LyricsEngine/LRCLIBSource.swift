import Foundation

/// Normalize a title/artist for fuzzy comparison: case- and diacritic-insensitive,
/// with collapsed whitespace. Used to safely match `/api/search` results.
func normalizeForMatch(_ s: String) -> String {
    s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
}

struct LRCLIBSource: LyricsSource {
    func fetchSyncedLyrics(for track: Track) async -> String? {
        try? await fetchSyncedLyricsWithError(for: track).get()
    }

    func fetchSyncedLyricsWithError(for track: Track) async -> Result<String?, Error> {
        let first = await request(title: track.title, artist: track.artist, album: track.album, duration: track.duration)
        if case .success(let s) = first, let r = s, !r.isEmpty { return .success(r) }
        return await request(title: track.title, artist: track.artist, album: nil, duration: track.duration)
    }

    private func request(title: String, artist: String, album: String?, duration: TimeInterval?) async -> Result<String?, Error> {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        var queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        if let album = album {
            queryItems.append(URLQueryItem(name: "album_name", value: album))
        }
        if let duration = duration, duration > 0 {
            queryItems.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }
        components.queryItems = queryItems
        guard let url = components.url else { return .success(nil) }

        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("Hum macOS app", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return .success(nil) }
            let json = try JSONDecoder().decode(LRCLIBResponse.self, from: data)
            return .success(json.syncedLyrics)
        } catch {
            return .failure(error)
        }
    }
}

private struct LRCLIBResponse: Decodable {
    let syncedLyrics: String?
}
