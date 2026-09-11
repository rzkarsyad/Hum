import Foundation

@MainActor
final class LyricsState: ObservableObject {
    @Published var lines: [LyricLine] = []
    @Published var isManuallyHidden: Bool = false
    @Published var noLyricsFound: Bool = false
    @Published var networkError: Bool = false
    @Published var fontSize: CGFloat = {
        let stored = UserDefaults.standard.double(forKey: "humFontSize")
        return stored >= 12 ? CGFloat(stored) : 20
    }()
    @Published var isMinimized: Bool = false

    /// Show an on-device translation under each lyric line (free, via the
    /// Translation framework). Persisted across launches.
    @Published var showTranslation: Bool = UserDefaults.standard.bool(forKey: "humShowTranslation")

    /// Translated text keyed by KaraokeItem index, populated by the translation
    /// task. Cleared on track change / when translation is off.
    @Published var translations: [Int: String] = [:]
}
