import AppKit
import Combine

func isSeek(reported: TimeInterval, interpolated: TimeInterval) -> Bool {
    abs(reported - interpolated) > 1.5
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
        let parts = result.components(separatedBy: "\t")
        switch parts.first {
        case "playing" where parts.count == 6:
            let track = Track(
                title: parts[1],
                artist: parts[2],
                album: parts[3],
                duration: TimeInterval(parts[5].replacingOccurrences(of: ",", with: "."))
            )
            let position = TimeInterval(parts[4].replacingOccurrences(of: ",", with: ".")) ?? 0
            if currentTrack != track {
                fetchArtwork()
                currentTrack = track
            }
            let interpolated = basePos + prePollDate.timeIntervalSince(baseD)
            if isSeek(reported: position, interpolated: interpolated) {
                playbackPosition = position
            }
            basePosition = position
            baseDate = prePollDate
            isPlaying = true
        case "paused":
            isPlaying = false
        default:
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

    private nonisolated static let pollScriptSource = """
        tell application "System Events"
            if not (exists process "Music") then return "not_running"
        end tell
        tell application "Music"
            if player state is playing then
                set t to current track
                return "playing\t" & (name of t) & "\t" & (artist of t) & "\t" & (album of t) & "\t" & (player position as string) & "\t" & (duration of t as string)
            else if player state is paused then
                return "paused"
            else
                return "stopped"
            end if
        end tell
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
        artworkQueue.async { [weak self] in
            let image = Self.fetchArtworkSync()
            Task { @MainActor [weak self] in
                guard let self, self.artworkGeneration == gen else { return }
                self.currentArtwork = image
            }
        }
    }

    // Only ever executed on serial artworkQueue — nonisolated(unsafe) is safe here.
    private nonisolated(unsafe) static let compiledArtworkScript: NSAppleScript? = {
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

    private nonisolated static func fetchArtworkSync() -> NSImage? {
        var err: NSDictionary?
        let desc = compiledArtworkScript?.executeAndReturnError(&err)
        guard err == nil, let data = desc?.data, !data.isEmpty else { return nil }
        return NSImage(data: data)
    }
}
