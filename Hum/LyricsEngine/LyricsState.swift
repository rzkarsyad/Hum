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
}
