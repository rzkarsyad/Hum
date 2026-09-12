import Foundation

/// Normalize a title/artist for fuzzy comparison: case- and diacritic-insensitive,
/// with collapsed whitespace. Used to safely match `/api/search` results.
func normalizeForMatch(_ s: String) -> String {
    s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
}

struct LRCLIBSearchResult: Decodable, Equatable {
    let trackName: String
    let artistName: String
    let duration: Double?
    let syncedLyrics: String?
}

/// Pick the best synced-lyrics result for a track, or nil if none match safely.
/// A result qualifies only when both its title and artist match (normalized):
/// equal, or the shorter is a whole-word prefix of the longer (so "(Official
/// Audio)"-style suffixes match, but "Artist" does not match "Other Artist").
/// When `duration` is given it breaks ties; without it, the first qualifying
/// result wins.
func bestSyncedMatch(results: [LRCLIBSearchResult], title: String, artist: String, duration: TimeInterval?) -> String? {
    func matches(_ a: String, _ b: String) -> Bool {
        let na = normalizeForMatch(a), nb = normalizeForMatch(b)
        guard !na.isEmpty, !nb.isEmpty else { return false }
        if na == nb { return true }
        // Word-boundary-aware prefix containment: the shorter must start the longer.
        let (shorter, longer) = na.count <= nb.count ? (na, nb) : (nb, na)
        return longer.hasPrefix(shorter) &&
            (longer.count == shorter.count || longer[longer.index(longer.startIndex, offsetBy: shorter.count)] == " ")
    }

    let candidates = results.filter {
        guard let synced = $0.syncedLyrics, !synced.isEmpty else { return false }
        return matches($0.trackName, title) && matches($0.artistName, artist)
    }
    guard !candidates.isEmpty else { return nil }

    guard let duration else { return candidates.first?.syncedLyrics }
    return candidates.min {
        abs(($0.duration ?? .greatestFiniteMagnitude) - duration) <
        abs(($1.duration ?? .greatestFiniteMagnitude) - duration)
    }?.syncedLyrics
}

/// Builds the `/api/get` URL for an exact lookup.
///
/// `duration` is sent only when positive: Spotify and the browser source can
/// report 0 before metadata settles, and `duration=0` turns a lookup that would
/// have hit into a miss.
func lrclibGetURL(title: String, artist: String, album: String?, duration: TimeInterval?) -> URL? {
    var components = URLComponents(string: "https://lrclib.net/api/get")!
    var queryItems = [
        URLQueryItem(name: "track_name", value: title),
        URLQueryItem(name: "artist_name", value: artist)
    ]
    if let album {
        queryItems.append(URLQueryItem(name: "album_name", value: album))
    }
    if let duration, duration > 0 {
        queryItems.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
    }
    components.queryItems = queryItems
    return components.url
}

/// Builds the fuzzy `/api/search` URL. Album and duration are deliberately left
/// out — they are often wrong or missing for browser playback, which is exactly
/// when this fallback is needed.
func lrclibSearchURL(title: String, artist: String) -> URL? {
    var components = URLComponents(string: "https://lrclib.net/api/search")!
    components.queryItems = [
        URLQueryItem(name: "track_name", value: title),
        URLQueryItem(name: "artist_name", value: artist)
    ]
    return components.url
}

/// Decodes the synced lyrics out of an `/api/get` response.
func parseLRCLIBLyrics(_ data: Data) throws -> String? {
    try JSONDecoder().decode(LRCLIBResponse.self, from: data).syncedLyrics
}

/// Decodes an `/api/search` response.
func parseLRCLIBSearchResults(_ data: Data) throws -> [LRCLIBSearchResult] {
    try JSONDecoder().decode([LRCLIBSearchResult].self, from: data)
}

struct LRCLIBSource: LyricsSource {
    func fetchSyncedLyrics(for track: Track) async -> String? {
        try? await fetchSyncedLyricsWithError(for: track).get()
    }

    func fetchSyncedLyricsWithError(for track: Track) async -> Result<String?, Error> {
        let first = await request(title: track.title, artist: track.artist, album: track.album, duration: track.duration)
        if case .success(let s) = first, let r = s, !r.isEmpty { return .success(r) }

        let second = await request(title: track.title, artist: track.artist, album: nil, duration: track.duration)
        if case .success(let s) = second, let r = s, !r.isEmpty { return .success(r) }

        // Fallback: fuzzy /api/search, then a safe title+artist match.
        let search = await searchRequest(title: track.title, artist: track.artist)
        switch search {
        case .success(let results):
            if let matched = bestSyncedMatch(results: results, title: track.title, artist: track.artist, duration: track.duration),
               !matched.isEmpty {
                return .success(matched)
            }
            // No confident match. Preserve a network error from the 2nd get, else "not found".
            if case .failure(let e) = second { return .failure(e) }
            return .success(nil)
        case .failure(let e):
            return .failure(e)
        }
    }

    private func request(title: String, artist: String, album: String?, duration: TimeInterval?) async -> Result<String?, Error> {
        guard let url = lrclibGetURL(title: title, artist: artist, album: album, duration: duration)
        else { return .success(nil) }

        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("Hum macOS app", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return .success(nil) }
            return .success(try parseLRCLIBLyrics(data))
        } catch {
            return .failure(error)
        }
    }

    private func searchRequest(title: String, artist: String) async -> Result<[LRCLIBSearchResult], Error> {
        guard let url = lrclibSearchURL(title: title, artist: artist) else { return .success([]) }

        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("Hum macOS app", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return .success([]) }
            return .success(try parseLRCLIBSearchResults(data))
        } catch {
            return .failure(error)
        }
    }
}

private struct LRCLIBResponse: Decodable {
    let syncedLyrics: String?
}
