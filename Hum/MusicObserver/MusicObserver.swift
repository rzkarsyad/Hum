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

/// A media player Hum can read over AppleScript, listed in priority order.
enum ScriptablePlayer: String, CaseIterable, Equatable {
    case appleMusic = "music"
    case spotify = "spotify"

    /// Process name as reported by System Events; also the `tell application` name.
    var appName: String {
        switch self {
        case .appleMusic: return "Music"
        case .spotify: return "Spotify"
        }
    }

    var source: PlayerSource {
        switch self {
        case .appleMusic: return .appleMusic
        case .spotify: return .spotify
        }
    }
}

/// Script that reports which player processes are currently running, as a
/// tab-separated list of `ScriptablePlayer` raw values.
///
/// It only ever *tells* System Events — which ships with macOS — and probes the
/// players by process name, which needs no terminology from the players
/// themselves. That keeps this script compilable on any Mac, whatever the user
/// has installed.
func runningPlayersScriptSource(_ players: [ScriptablePlayer]) -> String {
    let probes = players
        .map { "        if (exists process \"\($0.appName)\") then set out to out & \"\($0.rawValue)\" & tab" }
        .joined(separator: "\n")
    return """
        set out to ""
        tell application "System Events"
        \(probes)
        end tell
        return out
        """
}

/// Poll script for a single player, in the tab-separated format `parsePollResult`
/// expects.
///
/// One script per player, never a combined one: `tell application "X"` makes
/// AppleScript resolve X's scripting terminology at *compile* time, so a
/// combined script cannot be compiled on a Mac that is missing any one of the
/// players — which would take the installed players down with it. Compile this
/// only once the player's process is actually seen running.
func pollScriptSource(for player: ScriptablePlayer) -> String {
    // Spotify reports duration in milliseconds; Apple Music in seconds.
    let duration = player == .spotify
        ? "(((duration of t) / 1000) as string)"
        : "(duration of t as string)"
    return """
        tell application "\(player.appName)"
            if player state is playing then
                set t to current track
                return "playing\t\(player.rawValue)\t" & (name of t) & "\t" & (artist of t) & "\t" & (album of t) & "\t" & (player position as string) & "\t" & \(duration)
            else if player state is paused then
                return "paused"
            end if
        end tell
        return "stopped"
        """
}

/// Parses the running-players probe output into players, in priority order.
func parseRunningPlayers(_ raw: String) -> [ScriptablePlayer] {
    let tags = Set(raw.components(separatedBy: "\t").filter { !$0.isEmpty })
    return ScriptablePlayer.allCases.filter { tags.contains($0.rawValue) }
}

/// Collapses the per-player outcomes into one: the first player that is actually
/// playing wins, otherwise a paused player, otherwise stopped.
func mergePlayerOutcomes(_ outcomes: [PollOutcome]) -> PollOutcome {
    if let playing = outcomes.first(where: { if case .playing = $0 { return true } else { return false } }) {
        return playing
    }
    return outcomes.contains(.paused) ? .paused : .stopped
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

/// How long to leave a player alone after its script failed to compile, before
/// trying again.
let playerScriptRetryCooldown: TimeInterval = 30

/// Whether a player whose script failed to compile should be retried yet.
///
/// A compile only fails when AppleScript cannot resolve the app — normally
/// because it is being replaced mid-update. Caching that failure for the rest of
/// the session would disable the player until Hum is relaunched, so it expires;
/// a cooldown keeps the 2 Hz poll from hammering a genuinely broken app.
/// A backwards clock jump (NTP, DST) retries rather than wedging.
func shouldRetryPlayerScript(lastFailure: Date, now: Date) -> Bool {
    let elapsed = now.timeIntervalSince(lastFailure)
    return elapsed < 0 || elapsed >= playerScriptRetryCooldown
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
    @Published private(set) var currentSource: PlayerSource = .appleMusic
    private var lastBrowserArtwork: Data?

    private let pollQueue = DispatchQueue(label: "com.hum.poll", qos: .userInteractive)
    private let artworkQueue = DispatchQueue(label: "com.hum.artwork", qos: .utility)
    private var artworkGeneration = 0
    private let browserSource: BrowserMediaSource

    init(browserSource: BrowserMediaSource = BrowserMediaSource()) {
        self.browserSource = browserSource
    }

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

        // Wake the poll immediately when browser now-playing changes, so the
        // window appears on play without waiting for the next 0.5s tick.
        browserSource.onUpdate = { [weak self] in
            Task { @MainActor [weak self] in self?.schedulePoll() }
        }
        browserSource.start()
    }

    func stop() {
        pollTimer?.invalidate(); pollTimer = nil
        displayTimer?.invalidate(); displayTimer = nil
        browserSource.stop()
    }

    // Captures main-actor state, then offloads AppleScript execution to background.
    private func schedulePoll() {
        let prePollDate = Date()
        let basePos = basePosition
        let baseD = baseDate

        pollQueue.async { [weak self] in
            guard let outcome = Self.pollPlayers() else { return }
            Task { @MainActor [weak self] in
                self?.applyPollResult(outcome, prePollDate: prePollDate, basePos: basePos, baseD: baseD)
            }
        }
    }

    private func applyPollResult(_ players: PollOutcome, prePollDate: Date, basePos: TimeInterval, baseD: Date) {
        let browser = browserSource.current(now: prePollDate)
        let outcome = mergeOutcome(
            appleScript: players,
            browser: browser?.snapshot,
            browserPosition: browser?.position ?? 0
        )
        switch outcome {
        case .playing(let poll):
            let trackChanged = (currentTrack != poll.track)
            if currentSource != poll.source { currentSource = poll.source }
            if trackChanged { currentTrack = poll.track }

            if poll.source == .browser {
                let art = browser?.snapshot.artworkData
                if trackChanged || art != lastBrowserArtwork {
                    lastBrowserArtwork = art
                    fetchArtwork(browserData: art)
                }
            } else if trackChanged {
                lastBrowserArtwork = nil
                fetchArtwork(browserData: nil)
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
            lastBrowserArtwork = nil
        }
    }

    private func interpolatePosition() {
        guard isPlaying else { return }
        playbackPosition = basePosition + Date().timeIntervalSince(baseDate)
    }

    // MARK: - Poll scripts (background)

    // The running-players probe only talks to System Events, so it compiles on
    // every Mac regardless of which players are installed.
    // Only ever executed on serial pollQueue — nonisolated(unsafe) is safe here.
    private nonisolated(unsafe) static let compiledRunningPlayersScript: NSAppleScript? = {
        var err: NSDictionary?
        let script = NSAppleScript(source: runningPlayersScriptSource(ScriptablePlayer.allCases))
        script?.compileAndReturnError(&err)
        return err == nil ? script : nil
    }()

    // Per-player scripts, compiled on first sight of that player's process — if
    // the process is running the app is installed, so AppleScript can always
    // resolve its terminology. Compiling a script for a *missing* app would pop
    // the "Where is …?" chooser panel or fail outright, so we never do it.
    // A failure is remembered with its time so the 2 Hz poll does not hammer a
    // broken compile, but it expires — see shouldRetryPlayerScript.
    // Only ever touched on serial pollQueue — nonisolated(unsafe) is safe here.
    private enum PlayerScript {
        case compiled(NSAppleScript)
        case failed(at: Date)
    }
    private nonisolated(unsafe) static var playerScripts: [ScriptablePlayer: PlayerScript] = [:]

    private nonisolated static func playerScript(for player: ScriptablePlayer) -> NSAppleScript? {
        switch playerScripts[player] {
        case .compiled(let script):
            return script
        case .failed(let at) where !shouldRetryPlayerScript(lastFailure: at, now: Date()):
            return nil
        case .failed, .none:
            break
        }

        var err: NSDictionary?
        let script = NSAppleScript(source: pollScriptSource(for: player))
        script?.compileAndReturnError(&err)
        guard err == nil, let script else {
            playerScripts[player] = .failed(at: Date())
            return nil
        }
        playerScripts[player] = .compiled(script)
        return script
    }

    private nonisolated static func run(_ script: NSAppleScript) -> String? {
        var err: NSDictionary?
        let result = script.executeAndReturnError(&err)
        return err == nil ? result.stringValue : nil
    }

    /// Polls each *running* player in priority order, stopping at the first one
    /// that is playing. Returns nil when the probe itself failed, so the caller
    /// can skip the tick instead of reporting a spurious stop.
    private nonisolated static func pollPlayers() -> PollOutcome? {
        guard let probe = compiledRunningPlayersScript, let raw = run(probe) else { return nil }
        var outcomes: [PollOutcome] = []
        for player in parseRunningPlayers(raw) {
            guard let script = playerScript(for: player), let out = run(script) else { continue }
            let outcome = parsePollResult(out)
            if case .playing = outcome { return outcome }
            outcomes.append(outcome)
        }
        return mergePlayerOutcomes(outcomes)
    }

    // MARK: - Artwork (background, cancellable via generation counter)

    private func fetchArtwork(browserData: Data?) {
        artworkGeneration += 1
        let gen = artworkGeneration
        let source = currentSource
        artworkQueue.async { [weak self] in
            let image = Self.fetchArtworkSync(source: source, browserData: browserData)
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

    private nonisolated static func fetchArtworkSync(source: PlayerSource, browserData: Data?) -> NSImage? {
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
            guard let data = browserData, !data.isEmpty else { return nil }
            return NSImage(data: data)
        }
    }
}
