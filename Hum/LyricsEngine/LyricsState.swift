import Foundation

@MainActor
final class LyricsState: ObservableObject {
    @Published var lines: [LyricLine] = []
    @Published var syncOffset: TimeInterval = 0
    @Published var isManuallyHidden: Bool = false
}
