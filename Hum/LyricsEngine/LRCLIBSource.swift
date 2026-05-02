import Foundation

struct LRCLIBSource: LyricsSource {
    func fetchSyncedLyrics(for track: Track) async -> String? {
        // Try with full info (title + artist + album)
        if let result = await request(title: track.title, artist: track.artist, album: track.album),
           !result.isEmpty {
            return result
        }
        // Fallback: try without album name
        return await request(title: track.title, artist: track.artist, album: nil)
    }

    private func request(title: String, artist: String, album: String?) async -> String? {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        var queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        if let album = album {
            queryItems.append(URLQueryItem(name: "album_name", value: album))
        }
        components.queryItems = queryItems
        guard let url = components.url else { return nil }

        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("Hum macOS app", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let json = try? JSONDecoder().decode(LRCLIBResponse.self, from: data) else { return nil }

        return json.syncedLyrics
    }
}

private struct LRCLIBResponse: Decodable {
    let syncedLyrics: String?
}
