import Foundation

struct LRCLIBSource: LyricsSource {
    func fetchSyncedLyrics(for track: Track) async -> String? {
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album)
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Hum macOS app", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let json = try? JSONDecoder().decode(LRCLIBResponse.self, from: data) else { return nil }

        return json.syncedLyrics
    }
}

private struct LRCLIBResponse: Decodable {
    let syncedLyrics: String?
}
