import SwiftUI

func activeIndex(in lines: [LyricLine], at position: TimeInterval) -> Int? {
    guard !lines.isEmpty else { return nil }
    var result: Int? = nil
    for (i, line) in lines.enumerated() {
        if line.timestamp <= position { result = i } else { break }
    }
    return result
}

struct KaraokeView: View {
    let lines: [LyricLine]
    @ObservedObject var musicObserver: MusicObserver
    let syncOffset: TimeInterval
    let fontSize: CGFloat

    @State private var scrollTarget: Int? = nil

    private var active: Int? {
        activeIndex(in: lines, at: musicObserver.playbackPosition + syncOffset)
    }

    private func lineDuration(for index: Int) -> TimeInterval {
        guard index + 1 < lines.count else { return 0.9 }
        let available = lines[index + 1].timestamp - lines[index].timestamp
        return max(available, 0.3)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    ZStack(alignment: .leading) {
                        Text(line.text)
                            .font(.system(size: fontSize, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(0.3)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if index == active {
                            Text(line.text)
                                .customAttribute(EmphasisAttribute())
                                .font(.system(size: fontSize, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.asymmetric(
                                    insertion: AnyTransition(TextTransition(duration: lineDuration(for: index))),
                                    removal: .opacity.animation(.easeOut(duration: 0.15))
                                ))
                        }
                    }
                    .padding(.horizontal, 16)
                    .id(index)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 24)
        }
        .scrollPosition(id: $scrollTarget, anchor: UnitPoint(x: 0.5, y: 0.35))
        .onChange(of: active) { _, idx in
            withAnimation(.spring(duration: 0.45, bounce: 0.0)) {
                scrollTarget = idx
            }
        }
    }
}
