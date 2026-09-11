import XCTest
@testable import Hum

final class MusicObserverTests: XCTestCase {

    func test_isSeekReturnsTrueWhenDiffExceedsThreshold() {
        XCTAssertTrue(isSeek(reported: 10.0, interpolated: 12.0))
    }

    func test_isSeekReturnsFalseWhenDiffWithinThreshold() {
        XCTAssertFalse(isSeek(reported: 10.0, interpolated: 10.3))
    }

    func test_isSeekReturnsFalseAtExactThreshold() {
        XCTAssertFalse(isSeek(reported: 10.0, interpolated: 11.5))
    }

    func test_isSeekHandlesBackwardSeek() {
        XCTAssertTrue(isSeek(reported: 5.0, interpolated: 10.0))
    }

    // MARK: - parsePollResult

    func test_parsePlayingAppleMusic() {
        let raw = "playing\tmusic\tBohemian Rhapsody\tQueen\tA Night at the Opera\t12.5\t354.0"
        guard case let .playing(r) = parsePollResult(raw) else {
            return XCTFail("expected .playing")
        }
        XCTAssertEqual(r.source, .appleMusic)
        XCTAssertEqual(r.track.title, "Bohemian Rhapsody")
        XCTAssertEqual(r.track.artist, "Queen")
        XCTAssertEqual(r.track.album, "A Night at the Opera")
        XCTAssertEqual(r.track.duration ?? 0, 354.0, accuracy: 0.001)
        XCTAssertEqual(r.position, 12.5, accuracy: 0.001)
    }

    func test_parsePlayingSpotify() {
        let raw = "playing\tspotify\tStarboy\tThe Weeknd\tStarboy\t30.0\t230.4"
        guard case let .playing(r) = parsePollResult(raw) else {
            return XCTFail("expected .playing")
        }
        XCTAssertEqual(r.source, .spotify)
        XCTAssertEqual(r.track.title, "Starboy")
        XCTAssertEqual(r.track.artist, "The Weeknd")
        XCTAssertEqual(r.position, 30.0, accuracy: 0.001)
        XCTAssertEqual(r.track.duration ?? 0, 230.4, accuracy: 0.001)
    }

    func test_parseHandlesCommaDecimalSeparator() {
        let raw = "playing\tmusic\tSong\tArtist\tAlbum\t12,5\t200,0"
        guard case let .playing(r) = parsePollResult(raw) else {
            return XCTFail("expected .playing")
        }
        XCTAssertEqual(r.position, 12.5, accuracy: 0.001)
        XCTAssertEqual(r.track.duration ?? 0, 200.0, accuracy: 0.001)
    }

    func test_parsePaused() {
        XCTAssertEqual(parsePollResult("paused"), .paused)
    }

    func test_parseStoppedAndNotRunning() {
        XCTAssertEqual(parsePollResult("stopped"), .stopped)
        XCTAssertEqual(parsePollResult("not_running"), .stopped)
    }

    func test_parseUnknownSourceFallsBackToStopped() {
        XCTAssertEqual(parsePollResult("playing\tdeezer\tt\ta\talb\t1\t2"), .stopped)
    }

    func test_parseMalformedFallsBackToStopped() {
        XCTAssertEqual(parsePollResult("playing\tmusic\ttoo\tfew"), .stopped)
    }

    // MARK: - mergeOutcome

    private func snap(playing: Bool, title: String = "Song") -> BrowserSnapshot {
        BrowserSnapshot(bundleID: "com.google.Chrome", title: title, artist: "A", album: "Al",
                        duration: 180, isPlaying: playing, elapsedTime: 10, playbackRate: 1,
                        timestamp: nil, artworkData: nil)
    }

    func test_merge_appleScriptPlayingWins() {
        let asPlaying = PollOutcome.playing(PollResult(source: .spotify,
            track: Track(title: "S", artist: "B", album: "C"), position: 5))
        let result = mergeOutcome(appleScript: asPlaying, browser: snap(playing: true), browserPosition: 99)
        XCTAssertEqual(result, asPlaying)
    }

    func test_merge_browserWinsWhenAppleScriptStopped() {
        let result = mergeOutcome(appleScript: .stopped, browser: snap(playing: true), browserPosition: 33)
        guard case let .playing(p) = result else { return XCTFail("expected .playing") }
        XCTAssertEqual(p.source, .browser)
        XCTAssertEqual(p.track.title, "Song")
        XCTAssertEqual(p.position, 33, accuracy: 0.001)
    }

    func test_merge_pausedBrowserDoesNotWin() {
        let result = mergeOutcome(appleScript: .stopped, browser: snap(playing: false), browserPosition: 1)
        XCTAssertEqual(result, .stopped)
    }

    func test_merge_noBrowserFallsBackToAppleScript() {
        XCTAssertEqual(mergeOutcome(appleScript: .paused, browser: nil, browserPosition: 0), .paused)
    }

    // MARK: - Optional player apps
    //
    // Regression guard: Hum must never force AppleScript to resolve a player's
    // scripting terminology unless that player is actually present. A script
    // that hard-codes `tell application "Spotify"` makes AppleScript resolve
    // Spotify at COMPILE time, which on a Mac without Spotify pops the
    // "Where is Spotify?" chooser panel or fails to compile outright.

    func test_runningPlayersScript_neverTellsAThirdPartyApp() {
        let script = runningPlayersScriptSource(ScriptablePlayer.allCases)
        // System Events is present on every Mac, so telling it is always safe.
        XCTAssertTrue(script.contains(#"tell application "System Events""#))
        // Probing by process name needs no terminology from the app itself.
        XCTAssertTrue(script.contains(#"exists process "Music""#))
        XCTAssertTrue(script.contains(#"exists process "Spotify""#))
        // …but the app itself must never be told, or the compile resolves it.
        XCTAssertFalse(script.contains(#"tell application "Spotify""#))
        XCTAssertFalse(script.contains(#"tell application "Music""#))
    }

    func test_pollScriptSource_isScopedToASinglePlayer() {
        let music = pollScriptSource(for: .appleMusic)
        XCTAssertTrue(music.contains(#"tell application "Music""#))
        XCTAssertFalse(music.contains("Spotify"))

        let spotify = pollScriptSource(for: .spotify)
        XCTAssertTrue(spotify.contains(#"tell application "Spotify""#))
        XCTAssertFalse(spotify.contains(#"tell application "Music""#))
    }

    func test_pollScriptSource_tagsItsOwnSource() {
        XCTAssertTrue(pollScriptSource(for: .appleMusic).contains("playing\tmusic\t"))
        XCTAssertTrue(pollScriptSource(for: .spotify).contains("playing\tspotify\t"))
    }

    func test_pollScriptSource_spotifyNormalizesMillisecondDuration() {
        XCTAssertTrue(pollScriptSource(for: .spotify).contains("/ 1000"))
        XCTAssertFalse(pollScriptSource(for: .appleMusic).contains("/ 1000"))
    }

    func test_pollScriptSource_reportsPausedAndStopped() {
        for player in ScriptablePlayer.allCases {
            let script = pollScriptSource(for: player)
            XCTAssertTrue(script.contains(#""paused""#), "\(player) must report paused")
            XCTAssertTrue(script.contains(#""stopped""#), "\(player) must report stopped")
        }
    }

    // MARK: - parseRunningPlayers

    func test_parseRunningPlayers_returnsPriorityOrder() {
        XCTAssertEqual(parseRunningPlayers("spotify\tmusic\t"), [.appleMusic, .spotify])
    }

    func test_parseRunningPlayers_handlesSingleAndEmpty() {
        XCTAssertEqual(parseRunningPlayers("spotify\t"), [.spotify])
        XCTAssertEqual(parseRunningPlayers(""), [])
        XCTAssertEqual(parseRunningPlayers("\t\t"), [])
    }

    func test_parseRunningPlayers_ignoresUnknownTags() {
        XCTAssertEqual(parseRunningPlayers("deezer\tmusic\t"), [.appleMusic])
    }

    // MARK: - mergePlayerOutcomes

    private func playing(_ source: PlayerSource) -> PollOutcome {
        .playing(PollResult(source: source,
                            track: Track(title: "T", artist: "A", album: "Al"),
                            position: 1))
    }

    func test_mergePlayerOutcomes_firstPlayingWins() {
        XCTAssertEqual(mergePlayerOutcomes([.paused, playing(.spotify)]), playing(.spotify))
    }

    func test_mergePlayerOutcomes_pausedBeatsStopped() {
        XCTAssertEqual(mergePlayerOutcomes([.stopped, .paused]), .paused)
    }

    func test_mergePlayerOutcomes_emptyIsStopped() {
        XCTAssertEqual(mergePlayerOutcomes([]), .stopped)
        XCTAssertEqual(mergePlayerOutcomes([.stopped]), .stopped)
    }
}
