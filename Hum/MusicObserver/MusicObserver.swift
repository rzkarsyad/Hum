import AppKit
import Combine

func isSeek(reported: TimeInterval, interpolated: TimeInterval) -> Bool {
    abs(reported - interpolated) > 1.5
}

/// Which media app a poll result came from. Raw values match the source tag
/// emitted by the AppleScript poll.
enum PlayerSource: String, Equatable {
    case appleMusic = "music"
    case spotify = "spotify"
    case browser = "browser"
}

struct PollResult: Equatable {
    let source: PlayerSource
    let track: Track
    let position: TimeInterval
}

enum PollOutcome: Equatable {
    case playing(PollResult)
    case paused
    case stopped
}

/// Parses the tab-separated string returned by the poll AppleScript into a
/// structured outcome. Pure and source-agnostic so it can be unit-tested.
/// Playing format: `playing\t<source>\t<title>\t<artist>\t<album>\t<position>\t<duration>`
func parsePollResult(_ raw: String) -> PollOutcome {
    let parts = raw.components(separatedBy: "\t")
    switch parts.first {
    case "playing" where parts.count == 7:
        guard let source = PlayerSource(rawValue: parts[1]) else { return .stopped }
        let position = TimeInterval(parts[5].replacingOccurrences(of: ",", with: ".")) ?? 0
        let duration = TimeInterval(parts[6].replacingOccurrences(of: ",", with: "."))
        let track = Track(title: parts[2], artist: parts[3], album: parts[4], duration: duration)
        return .playing(PollResult(source: source, track: track, position: position))
    case "paused":
        return .paused
    default:
        return .stopped
    }
}

/// Combine the AppleScript outcome (Apple Music / Spotify) with the latest
/// browser snapshot. Priority: a *playing* Apple Music / Spotify always wins;
/// otherwise a *playing* browser wins; otherwise reflect the AppleScript state.
func mergeOutcome(appleScript: PollOutcome, browser: BrowserSnapshot?, browserPosition: TimeInterval) -> PollOutcome {
    if case .playing = appleScript { return appleScript }
    if let b = browser, b.isPlaying {
        let track = Track(title: b.title, artist: b.artist, album: b.album, duration: b.duration)
        return .playing(PollResult(source: .browser, track: track, position: browserPosition))
    }
    return appleScript
}

@MainActor
final class MusicObserver: ObservableObject {
    @Published private(set) var currentTrack: Track? = nil
    @Published private(set) var playbackPosition: TimeInterval = 0
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentArtwork: NSImage? = nil

    private var pollTimer: Timer?
    private var displayTimer: Timer?
    private var basePosition: TimeInterval = 0
    private var baseDate: Date = Date()
    private var currentSource: PlayerSource = .appleMusic

    private let pollQueue = DispatchQueue(label: "com.hum.poll", qos: .userInteractive)
    private let artworkQueue = DispatchQueue(label: "com.hum.artwork", qos: .utility)
    private var artworkGeneration = 0

    func start() {
        let poll = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.schedulePoll() }
        }
        RunLoop.main.add(poll, forMode: .common)
        pollTimer = poll

        let display = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.interpolatePosition() }
        }
        RunLoop.main.add(display, forMode: .common)
        displayTimer = display
    }

    func stop() {
        pollTimer?.invalidate(); pollTimer = nil
        displayTimer?.invalidate(); displayTimer = nil
    }

    // Captures main-actor state, then offloads AppleScript execution to background.
    private func schedulePoll() {
        let prePollDate = Date()
        let basePos = basePosition
        let baseD = baseDate

        pollQueue.async { [weak self] in
            guard let result = Self.executePollScript() else { return }
            Task { @MainActor [weak self] in
                self?.applyPollResult(result, prePollDate: prePollDate, basePos: basePos, baseD: baseD)
            }
        }
    }

    private func applyPollResult(_ result: String, prePollDate: Date, basePos: TimeInterval, baseD: Date) {
        switch parsePollResult(result) {
        case .playing(let poll):
            if currentTrack != poll.track {
                currentSource = poll.source
                fetchArtwork()
                currentTrack = poll.track
            }
            let interpolated = basePos + prePollDate.timeIntervalSince(baseD)
            if isSeek(reported: poll.position, interpolated: interpolated) {
                playbackPosition = poll.position
            }
            basePosition = poll.position
            baseDate = prePollDate
            isPlaying = true
        case .paused:
            isPlaying = false
        case .stopped:
            isPlaying = false
            currentTrack = nil
            currentArtwork = nil
            playbackPosition = 0
            basePosition = 0
            baseDate = prePollDate
        }
    }

    private func interpolatePosition() {
        guard isPlaying else { return }
        playbackPosition = basePosition + Date().timeIntervalSince(baseDate)
    }

    // MARK: - Poll script (background)

    // Polls Apple Music and Spotify in a single pass. Apple Music takes priority
    // when both are playing. `exists process` guards ensure we never *launch*
    // either app — `tell application "X"` alone would auto-launch it.
    // Spotify reports duration in milliseconds, so it is normalized to seconds.
    private nonisolated static let pollScriptSource = """
        set musicRunning to false
        set spotifyRunning to false
        tell application "System Events"
            if (exists process "Music") then set musicRunning to true
            if (exists process "Spotify") then set spotifyRunning to true
        end tell

        if musicRunning then
            tell application "Music"
                if player state is playing then
                    set t to current track
                    return "playing\tmusic\t" & (name of t) & "\t" & (artist of t) & "\t" & (album of t) & "\t" & (player position as string) & "\t" & (duration of t as string)
                end if
            end tell
        end if

        if spotifyRunning then
            tell application "Spotify"
                if player state is playing then
                    set t to current track
                    return "playing\tspotify\t" & (name of t) & "\t" & (artist of t) & "\t" & (album of t) & "\t" & (player position as string) & "\t" & (((duration of t) / 1000) as string)
                end if
            end tell
        end if

        if musicRunning then
            tell application "Music"
                if player state is paused then return "paused"
            end tell
        end if

        if spotifyRunning then
            tell application "Spotify"
                if player state is paused then return "paused"
            end tell
        end if

        return "stopped"
        """

    // Only ever executed on serial pollQueue — nonisolated(unsafe) is safe here.
    private nonisolated(unsafe) static let compiledPollScript: NSAppleScript? = {
        var err: NSDictionary?
        let script = NSAppleScript(source: pollScriptSource)
        script?.compileAndReturnError(&err)
        return err == nil ? script : nil
    }()

    private nonisolated static func executePollScript() -> String? {
        var err: NSDictionary?
        let result = compiledPollScript?.executeAndReturnError(&err)
        return err == nil ? result?.stringValue : nil
    }

    // MARK: - Artwork (background, cancellable via generation counter)

    private func fetchArtwork() {
        artworkGeneration += 1
        let gen = artworkGeneration
        let source = currentSource
        artworkQueue.async { [weak self] in
            let image = Self.fetchArtworkSync(source: source)
            Task { @MainActor [weak self] in
                guard let self, self.artworkGeneration == gen else { return }
                self.currentArtwork = image
            }
        }
    }

    // Apple Music exposes artwork as embedded raw data.
    // Only ever executed on serial artworkQueue — nonisolated(unsafe) is safe here.
    private nonisolated(unsafe) static let compiledMusicArtworkScript: NSAppleScript? = {
        let source = """
            tell application "System Events"
                if not (exists process "Music") then return ""
            end tell
            tell application "Music"
                if player state is playing then
                    try
                        return raw data of artwork 1 of current track
                    end try
                end if
            end tell
            """
        var err: NSDictionary?
        let script = NSAppleScript(source: source)
        script?.compileAndReturnError(&err)
        return err == nil ? script : nil
    }()

    // Spotify exposes artwork as a remote URL that must be downloaded.
    // Only ever executed on serial artworkQueue — nonisolated(unsafe) is safe here.
    private nonisolated(unsafe) static let compiledSpotifyArtworkURLScript: NSAppleScript? = {
        let source = """
            tell application "System Events"
                if not (exists process "Spotify") then return ""
            end tell
            tell application "Spotify"
                if player state is playing then
                    try
                        return artwork url of current track
                    end try
                end if
            end tell
            return ""
            """
        var err: NSDictionary?
        let script = NSAppleScript(source: source)
        script?.compileAndReturnError(&err)
        return err == nil ? script : nil
    }()

    private nonisolated static func fetchArtworkSync(source: PlayerSource) -> NSImage? {
        switch source {
        case .appleMusic:
            var err: NSDictionary?
            let desc = compiledMusicArtworkScript?.executeAndReturnError(&err)
            guard err == nil, let data = desc?.data, !data.isEmpty else { return nil }
            return NSImage(data: data)
        case .spotify:
            var err: NSDictionary?
            let desc = compiledSpotifyArtworkURLScript?.executeAndReturnError(&err)
            guard err == nil,
                  let urlString = desc?.stringValue,
                  let url = URL(string: urlString),
                  let data = try? Data(contentsOf: url),
                  !data.isEmpty
            else { return nil }
            return NSImage(data: data)
        case .browser:
            return nil  // replaced in browser-integration task
        }
    }
}
