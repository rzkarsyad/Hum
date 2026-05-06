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

    private var pollTimer: Timer?
    private var displayTimer: Timer?
    private var basePosition: TimeInterval = 0
    private var baseDate: Date = Date()

    func start() {
        // Poll Apple Music every 500ms for track/state/position anchor
        let poll = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(poll, forMode: .common)
        pollTimer = poll

        // Interpolate position at ~60fps between polls for sub-16ms accuracy
        let display = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.interpolatePosition() }
        }
        RunLoop.main.add(display, forMode: .common)
        displayTimer = display
    }

    func stop() {
        pollTimer?.invalidate(); pollTimer = nil
        displayTimer?.invalidate(); displayTimer = nil
    }

    private func poll() {
        let prePollDate = Date()
        guard let result = runAppleScript(pollScript) else { return }
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
            if currentTrack != track { currentTrack = track }
            let interpolated = basePosition + prePollDate.timeIntervalSince(baseDate)
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
            playbackPosition = 0
            basePosition = 0
        }
    }

    private func interpolatePosition() {
        guard isPlaying else { return }
        // Estimate current position: anchor + time elapsed since anchor
        playbackPosition = basePosition + Date().timeIntervalSince(baseDate)
    }

    private let pollScript = """
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

    private lazy var compiledScript: NSAppleScript? = {
        var error: NSDictionary?
        let script = NSAppleScript(source: pollScript)
        script?.compileAndReturnError(&error)
        return error == nil ? script : nil
    }()

    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let result = compiledScript?.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return result?.stringValue
    }
}
