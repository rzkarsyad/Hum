import AppKit
import Combine

@MainActor
final class MusicObserver: ObservableObject {
    @Published private(set) var currentTrack: Track? = nil
    @Published private(set) var playbackPosition: TimeInterval = 0
    @Published private(set) var isPlaying: Bool = false

    private var timer: Timer?

    func start() {
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        guard let result = runAppleScript(pollScript) else { return }
        let parts = result.components(separatedBy: "\t")

        switch parts.first {
        case "playing" where parts.count == 5:
            let track = Track(title: parts[1], artist: parts[2], album: parts[3])
            let position = TimeInterval(parts[4]) ?? 0
            if currentTrack != track { currentTrack = track }
            playbackPosition = position
            isPlaying = true
        case "paused":
            isPlaying = false
        default:
            isPlaying = false
            currentTrack = nil
            playbackPosition = 0
        }
    }

    private let pollScript = """
        tell application "System Events"
            if not (exists process "Music") then return "not_running"
        end tell
        tell application "Music"
            if player state is playing then
                set t to current track
                return "playing\t" & (name of t) & "\t" & (artist of t) & "\t" & (album of t) & "\t" & (player position as string)
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
