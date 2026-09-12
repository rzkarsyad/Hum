import XCTest
@testable import Hum

/// The request and decode layer every lyric lookup goes through. When it breaks
/// nothing crashes — the lyrics simply never appear — so it is worth pinning.
final class LRCLIBRequestTests: XCTestCase {

    /// Reads a query value back out of a built URL, so the assertions are about
    /// what the server receives rather than about Foundation's escaping rules.
    private func query(_ url: URL?, _ name: String) -> String? {
        guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        return components.queryItems?.first { $0.name == name }?.value
    }

    private func names(_ url: URL?) -> [String] {
        guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return [] }
        return (components.queryItems ?? []).map(\.name)
    }

    // MARK: - /api/get

    func test_getURL_pointsAtTheGetEndpoint() {
        let url = lrclibGetURL(title: "Sadrah", artist: "For Revenge", album: nil, duration: nil)
        XCTAssertEqual(url?.host, "lrclib.net")
        XCTAssertEqual(url?.path, "/api/get")
        XCTAssertEqual(url?.scheme, "https")
    }

    func test_getURL_carriesTitleAndArtist() {
        let url = lrclibGetURL(title: "Sadrah", artist: "For Revenge", album: nil, duration: nil)
        XCTAssertEqual(query(url, "track_name"), "Sadrah")
        XCTAssertEqual(query(url, "artist_name"), "For Revenge")
    }

    func test_getURL_includesAlbumOnlyWhenPresent() {
        let with = lrclibGetURL(title: "T", artist: "A", album: "Perayaan Patah Hati", duration: nil)
        XCTAssertEqual(query(with, "album_name"), "Perayaan Patah Hati")

        let without = lrclibGetURL(title: "T", artist: "A", album: nil, duration: nil)
        XCTAssertFalse(names(without).contains("album_name"))
    }

    func test_getURL_roundsDurationToWholeSeconds() {
        XCTAssertEqual(query(lrclibGetURL(title: "T", artist: "A", album: nil, duration: 230.4), "duration"), "230")
        XCTAssertEqual(query(lrclibGetURL(title: "T", artist: "A", album: nil, duration: 230.6), "duration"), "231")
    }

    func test_getURL_omitsNonPositiveDuration() {
        // Spotify and browser sources can report 0 before metadata settles; sending
        // duration=0 makes an exact lookup miss that would otherwise have hit.
        XCTAssertFalse(names(lrclibGetURL(title: "T", artist: "A", album: nil, duration: 0)).contains("duration"))
        XCTAssertFalse(names(lrclibGetURL(title: "T", artist: "A", album: nil, duration: nil)).contains("duration"))
    }

    func test_getURL_survivesCharactersThatWouldBreakAQueryString() {
        let url = lrclibGetURL(title: "Rock & Roll (Live) ?", artist: "Sam + Dave", album: "100% Pure", duration: nil)
        XCTAssertEqual(query(url, "track_name"), "Rock & Roll (Live) ?")
        XCTAssertEqual(query(url, "artist_name"), "Sam + Dave")
        XCTAssertEqual(query(url, "album_name"), "100% Pure")
    }

    func test_getURL_survivesNonLatinTitles() {
        let url = lrclibGetURL(title: "밤편지", artist: "아이유", album: nil, duration: nil)
        XCTAssertEqual(query(url, "track_name"), "밤편지")
        XCTAssertEqual(query(url, "artist_name"), "아이유")
    }

    // MARK: - /api/search

    func test_searchURL_pointsAtTheSearchEndpointWithOnlyTitleAndArtist() {
        let url = lrclibSearchURL(title: "Sadrah", artist: "For Revenge")
        XCTAssertEqual(url?.path, "/api/search")
        XCTAssertEqual(query(url, "track_name"), "Sadrah")
        XCTAssertEqual(query(url, "artist_name"), "For Revenge")
        XCTAssertEqual(names(url).sorted(), ["artist_name", "track_name"])
    }

    // MARK: - Decoding

    func test_decodesSyncedLyricsFromAGetResponse() throws {
        let json = #"{"id":1,"trackName":"Sadrah","syncedLyrics":"[00:12.00]baris pertama"}"#
        XCTAssertEqual(try parseLRCLIBLyrics(Data(json.utf8)), "[00:12.00]baris pertama")
    }

    func test_getResponseWithoutSyncedLyricsIsNil() throws {
        XCTAssertNil(try parseLRCLIBLyrics(Data(#"{"syncedLyrics":null}"#.utf8)))
        XCTAssertNil(try parseLRCLIBLyrics(Data(#"{"plainLyrics":"no timestamps"}"#.utf8)))
    }

    func test_getResponseIgnoresUnknownFields() throws {
        // The API adds fields over time; that must not break an existing client.
        let json = #"{"syncedLyrics":"[00:01.00]x","somethingNew":{"nested":true},"instrumental":false}"#
        XCTAssertEqual(try parseLRCLIBLyrics(Data(json.utf8)), "[00:01.00]x")
    }

    func test_malformedGetResponseThrows() {
        XCTAssertThrowsError(try parseLRCLIBLyrics(Data("not json".utf8)))
    }

    func test_decodesSearchResults() throws {
        let json = """
        [{"trackName":"Sadrah","artistName":"For Revenge","duration":253.0,"syncedLyrics":"[00:10.00]a"},
         {"trackName":"Sadrah","artistName":"For Revenge","duration":null,"syncedLyrics":null}]
        """
        let results = try parseLRCLIBSearchResults(Data(json.utf8))
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0], LRCLIBSearchResult(trackName: "Sadrah", artistName: "For Revenge",
                                                      duration: 253.0, syncedLyrics: "[00:10.00]a"))
        XCTAssertNil(results[1].duration)
        XCTAssertNil(results[1].syncedLyrics)
    }

    func test_emptySearchResultsDecodeToAnEmptyArray() throws {
        XCTAssertEqual(try parseLRCLIBSearchResults(Data("[]".utf8)), [])
    }

    func test_malformedSearchResponseThrows() {
        XCTAssertThrowsError(try parseLRCLIBSearchResults(Data(#"{"not":"an array"}"#.utf8)))
    }

    // MARK: - The two layers together

    func test_aDecodedSearchResponseFeedsTheMatcher() throws {
        let json = """
        [{"trackName":"Sadrah (Live)","artistName":"For Revenge","duration":250.0,"syncedLyrics":"[00:01.00]live"},
         {"trackName":"Sadrah","artistName":"For Revenge","duration":253.0,"syncedLyrics":"[00:01.00]studio"}]
        """
        let results = try parseLRCLIBSearchResults(Data(json.utf8))
        let matched = bestSyncedMatch(results: results, title: "Sadrah", artist: "For Revenge", duration: 253)
        XCTAssertEqual(matched, "[00:01.00]studio", "the duration tiebreak should pick the studio cut")
    }
}
