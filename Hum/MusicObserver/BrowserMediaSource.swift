import Foundation

/// A now-playing snapshot for media playing in a browser, derived from the
/// MediaRemote adapter stream. Times are in seconds.
struct BrowserSnapshot: Equatable {
    let bundleID: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval?
    let isPlaying: Bool
    let elapsedTime: TimeInterval
    let playbackRate: Double
    let timestamp: Date?   // when elapsedTime was sampled (MediaRemote), for accurate extrapolation
    let artworkData: Data?
}

private let iso8601Formatter = ISO8601DateFormatter()

/// Extrapolate the live playback position from a sampled position and its anchor
/// time. The adapter only emits on state changes, so between emits the position
/// must be projected forward from `anchor` (the media's own timestamp) — anchoring
/// to receipt time instead would lag by however long the snapshot is old.
func livePosition(elapsedTime: TimeInterval, anchor: Date, rate: Double, now: Date) -> TimeInterval {
    let effectiveRate = rate == 0 ? 1.0 : rate
    return max(0, elapsedTime + now.timeIntervalSince(anchor) * effectiveRate)
}

/// Outcome of parsing one now-playing JSON line.
enum BrowserParse: Equatable {
    case browser(BrowserSnapshot)  // a browser is the now-playing app (may be paused)
    case other                     // valid now-playing info, but not a browser
    case ignore                    // unparseable / no usable info — keep previous state
}

/// Bundle identifiers of browsers whose media we surface. Chromium variants and
/// Safari report MediaSession metadata to macOS Now Playing; Firefox is included
/// best-effort.
func isBrowserBundleID(_ id: String) -> Bool {
    let browsers: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.dev", "com.google.Chrome.canary",
        "com.apple.Safari", "com.apple.SafariTechnologyPreview",
        "company.thebrowser.Browser",            // Arc
        "com.brave.Browser", "com.brave.Browser.beta", "com.brave.Browser.nightly",
        "com.microsoft.edgemac", "com.microsoft.edgemac.beta",
        "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition",
        "com.operasoftware.Opera", "com.operasoftware.OperaGX",
        "com.vivaldi.Vivaldi",
        "ru.yandex.desktop.yandex-browser",
    ]
    return browsers.contains(id)
}

/// Parse one line from the adapter into a structured outcome. The `stream`
/// command wraps the now-playing dictionary in an envelope
/// (`{"type":"data","diff":...,"payload":{...}}`) while `get` emits the flat
/// dictionary directly. We run `stream` with `--no-diff` so every payload is the
/// full current state; here we unwrap the envelope (if present) and classify it.
func parseBrowserNowPlaying(_ jsonLine: String) -> BrowserParse {
    guard let data = jsonLine.data(using: .utf8),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return .ignore }
    let nowPlaying = (root["payload"] as? [String: Any]) ?? root
    return classifyNowPlaying(nowPlaying)
}

/// Classify a now-playing dictionary (same keys as the adapter's `get` output).
/// An empty dictionary (nothing playing) classifies as `.other`, which clears any
/// previously held browser snapshot.
func classifyNowPlaying(_ obj: [String: Any]) -> BrowserParse {
    let bundleID = (obj["bundleIdentifier"] as? String) ?? ""
    let parentID = (obj["parentApplicationBundleIdentifier"] as? String) ?? ""
    let isBrowser = isBrowserBundleID(bundleID) || isBrowserBundleID(parentID)
    guard isBrowser else { return .other }

    guard let title = obj["title"] as? String, !title.isEmpty else { return .other }
    let effectiveID = isBrowserBundleID(bundleID) ? bundleID : parentID

    var artwork: Data?
    if let b64 = obj["artworkData"] as? String { artwork = Data(base64Encoded: b64) }

    var timestamp: Date?
    if let tsStr = obj["timestamp"] as? String { timestamp = iso8601Formatter.date(from: tsStr) }

    return .browser(BrowserSnapshot(
        bundleID: effectiveID,
        title: title,
        artist: (obj["artist"] as? String) ?? "",
        album: (obj["album"] as? String) ?? "",
        duration: obj["duration"] as? Double,
        isPlaying: (obj["playing"] as? Bool) ?? false,
        elapsedTime: (obj["elapsedTime"] as? Double) ?? 0,
        playbackRate: (obj["playbackRate"] as? Double) ?? 1.0,
        timestamp: timestamp,
        artworkData: artwork
    ))
}

/// Owns the `/usr/bin/perl` MediaRemote adapter subprocess and exposes the latest
/// browser now-playing snapshot. Thread-safe; safe to call `current(now:)` from
/// the main actor. Degrades silently if the adapter is unavailable.
final class BrowserMediaSource {
    /// Fired (on a background queue) when the playing track or play-state changes,
    /// so the observer can pick up the new now-playing immediately instead of
    /// waiting for the next poll tick.
    var onUpdate: (() -> Void)?

    private let lock = NSLock()
    private var snapshot: BrowserSnapshot?
    private var receivedAt = Date()
    private var lastNotifiedKey: String?

    private var process: Process?
    private var buffer = Data()
    private var failureCount = 0
    private var isStopped = false
    private let maxFailures = 5

    func start() {
        isStopped = false
        guard adapterAvailable() else {
            NSLog("[Hum] MediaRemote adapter unavailable — browser detection disabled.")
            return
        }
        launchStream()
    }

    func stop() {
        isStopped = true
        process?.terminate()
        process = nil
    }

    /// Latest playing browser snapshot with a live-extrapolated position, or nil.
    func current(now: Date) -> (snapshot: BrowserSnapshot, position: TimeInterval)? {
        lock.lock(); defer { lock.unlock() }
        guard let s = snapshot, s.isPlaying else { return nil }
        // Anchor to the media's own timestamp when available — the snapshot may be
        // many seconds old (the adapter only emits on change), and receipt time
        // would put us that far behind the real position.
        let anchor = s.timestamp ?? receivedAt
        let pos = livePosition(elapsedTime: s.elapsedTime, anchor: anchor, rate: s.playbackRate, now: now)
        return (s, pos)
    }

    // MARK: - Paths

    private static func adapterDir() -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent("MediaRemoteAdapter", isDirectory: true)
    }

    private func adapterAvailable() -> Bool {
        guard let dir = Self.adapterDir() else { return false }
        let fm = FileManager.default
        return fm.fileExists(atPath: dir.appendingPathComponent("mediaremote-adapter.pl").path)
            && fm.fileExists(atPath: dir.appendingPathComponent("MediaRemoteAdapter.framework").path)
            && fm.fileExists(atPath: "/usr/bin/perl")
    }

    // MARK: - Stream

    private func launchStream() {
        guard let dir = Self.adapterDir() else { return }
        let script = dir.appendingPathComponent("mediaremote-adapter.pl").path
        let framework = dir.appendingPathComponent("MediaRemoteAdapter.framework").path

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        proc.arguments = [script, framework, "stream", "--no-diff"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            self?.ingest(chunk)
        }

        proc.terminationHandler = { [weak self] _ in
            guard let self, !self.isStopped else { return }
            self.failureCount += 1
            guard self.failureCount <= self.maxFailures else {
                NSLog("[Hum] MediaRemote adapter failed repeatedly — browser detection disabled.")
                return
            }
            let delay = min(pow(2.0, Double(self.failureCount)), 30)
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, !self.isStopped else { return }
                self.launchStream()
            }
        }

        do {
            try proc.run()
            lock.lock(); process = proc; lock.unlock()
        } catch {
            NSLog("[Hum] Failed to launch MediaRemote adapter: \(error)")
        }
    }

    private func ingest(_ chunk: Data) {
        var completeLines: [String] = []
        lock.lock()
        buffer.append(chunk)
        while let nl = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer.subdata(in: buffer.startIndex..<nl)
            buffer.removeSubrange(buffer.startIndex...nl)
            if let str = String(data: lineData, encoding: .utf8) { completeLines.append(str) }
        }
        lock.unlock()

        for line in completeLines {
            switch parseBrowserNowPlaying(line) {
            case .browser(let s):
                lock.lock(); snapshot = s; receivedAt = Date(); lock.unlock()
                notifyIfChanged(key: "\(s.bundleID)|\(s.title)|\(s.isPlaying)")
            case .other:
                lock.lock(); snapshot = nil; lock.unlock()
                notifyIfChanged(key: "")
            case .ignore:
                break  // keep previous state
            }
        }
    }

    /// Invoke `onUpdate` only when the track/play-state identity actually changes,
    /// so an immediate re-poll fires on play/track changes without spamming on
    /// every (e.g. artwork-only) stream emit.
    private func notifyIfChanged(key: String) {
        lock.lock()
        let changed = key != lastNotifiedKey
        lastNotifiedKey = key
        lock.unlock()
        if changed { onUpdate?() }
    }
}
