import Foundation

struct LRCLIBSource: LyricsSource {
    func fetchSyncedLyrics(for track: Track) async -> String? {
        if let result = await request(title: track.title, artist: track.artist, album: track.album, duration: track.duration),
           !result.isEmpty {
            return result
        }
        return await request(title: track.title, artist: track.artist, album: nil, duration: track.duration)
    }

    private func request(title: String, artist: String, album: String?, duration: TimeInterval?) async -> String? {
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
