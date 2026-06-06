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
    let artworkData: Data?
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

/// Parse one NDJSON line from the adapter stream into a structured outcome.
func parseBrowserNowPlaying(_ jsonLine: String) -> BrowserParse {
    guard let data = jsonLine.data(using: .utf8),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return .ignore }

    let bundleID = (obj["bundleIdentifier"] as? String) ?? ""
    let parentID = (obj["parentApplicationBundleIdentifier"] as? String) ?? ""
    let isBrowser = isBrowserBundleID(bundleID) || isBrowserBundleID(parentID)
    guard isBrowser else { return .other }

    guard let title = obj["title"] as? String, !title.isEmpty else { return .other }
    let effectiveID = isBrowserBundleID(bundleID) ? bundleID : parentID

    var artwork: Data?
    if let b64 = obj["artworkData"] as? String { artwork = Data(base64Encoded: b64) }

    return .browser(BrowserSnapshot(
        bundleID: effectiveID,
        title: title,
        artist: (obj["artist"] as? String) ?? "",
        album: (obj["album"] as? String) ?? "",
        duration: obj["duration"] as? Double,
        isPlaying: (obj["playing"] as? Bool) ?? false,
        elapsedTime: (obj["elapsedTime"] as? Double) ?? 0,
        playbackRate: (obj["playbackRate"] as? Double) ?? 1.0,
        artworkData: artwork
    ))
}
