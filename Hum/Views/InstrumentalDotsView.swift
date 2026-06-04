import SwiftUI

/// Three dots whose individual fill amounts (0...1) drive their opacity.
struct DotsRow: View {
    let fills: [Double]      // exactly 3 values, 0...1
    let fontSize: CGFloat

    private var dotSize: CGFloat { max(8, fontSize * 0.32) }
    private var spacing: CGFloat { dotSize * 0.9 }
    private let dimOpacity: Double = 0.25

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3, id: \.self) { i in
                let fill = i < fills.count ? fills[i] : 0
                Circle()
                    .fill(Color.white)
                    .frame(width: dotSize, height: dotSize)
                    .opacity(dimOpacity + (1 - dimOpacity) * fill)
            }
        }
    }
}

/// Live instrumental indicator: observes MusicObserver and fills the dots as the
/// gap between `start` and `end` elapses. Updates at 60fps independently of the
/// enclosing (equatable) KaraokeView.
struct InstrumentalDotsView: View {
    let start: TimeInterval
    let end: TimeInterval
    let fontSize: CGFloat
    @ObservedObject var clock: MusicObserver

    private var progress: Double {
        guard end > start else { return 0 }
        return min(max((clock.playbackPosition - start) / (end - start), 0), 1)
    }

    var body: some View {
        DotsRow(fills: (0..<3).map { dotFill($0, progress: progress) }, fontSize: fontSize)
    }
}
