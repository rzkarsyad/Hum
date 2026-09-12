import Foundation

/// The interpolated playback position, published on an object of its own.
///
/// The position advances at display rate. Publishing it from `MusicObserver`
/// invalidated every view observing that object, in practice the whole lyrics
/// window, 60 times a second, which drove a full SwiftUI render and AppKit
/// layout pass per frame. The only thing that genuinely animates with the raw
/// position is the instrumental dots row, so the tick lives here: the dots
/// observe this clock, and everything else observes `MusicObserver` without
/// being woken by it.
@MainActor
final class PlaybackClock: ObservableObject {
    @Published private(set) var position: TimeInterval = 0

    func update(_ position: TimeInterval) {
        self.position = position
    }
}
