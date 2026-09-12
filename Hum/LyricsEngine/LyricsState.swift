import Foundation

@MainActor
final class LyricsState: ObservableObject {
    @Published var lines: [LyricLine] = [] {
        didSet {
            items = buildItems(from: lines)
            refreshActiveItem()
        }
    }

    /// Display list derived from `lines`. Built once per song: it used to be
    /// rebuilt inside the window's body, which ran at display rate, so the whole
    /// song was re-materialised and then compared away 60 times a second.
    @Published private(set) var items: [KaraokeItem] = []

    /// Index of the item currently being sung, or nil before the first one.
    /// Republished only when it actually changes, about once a line, so the
    /// position tick does not invalidate the window on every frame.
    @Published private(set) var activeItem: Int?

    @Published var isManuallyHidden: Bool = false
    @Published var noLyricsFound: Bool = false
    @Published var networkError: Bool = false
    @Published var fontSize: CGFloat = {
        let stored = UserDefaults.standard.double(forKey: "humFontSize")
        return stored >= 12 ? CGFloat(stored) : 20
    }()
    @Published var isMinimized: Bool = false

    private var position: TimeInterval = 0

    /// Feed in the latest playback position. Cheap to call at any rate: it only
    /// publishes when the resulting active item differs from the current one.
    func updatePosition(_ position: TimeInterval) {
        self.position = position
        refreshActiveItem()
    }

    private func refreshActiveItem() {
        let index = activeItemIndex(in: items, at: position)
        if index != activeItem { activeItem = index }
    }
}
