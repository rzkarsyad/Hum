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

    private var adjustedPosition: TimeInterval {
        musicObserver.playbackPosition + syncOffset
    }

    private var active: Int? {
        activeIndex(in: lines, at: adjustedPosition)
    }

    private func words(for index: Int) -> [WordToken] {
        let line = lines[index]
        let next = index + 1 < lines.count ? lines[index + 1].timestamp : nil
        return wordTokens(for: line, nextTimestamp: next)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Group {
                            if index == active {
                                WordFlowView(
                                    words: words(for: index),
                                    playbackPosition: adjustedPosition
                                )
                                .transition(.opacity.animation(.easeIn(duration: 0.15)))
                            } else {
                                Text(line.text)
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                                    .opacity(0.3)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 16)
                        .id(index)
                    }
                }
                .padding(.vertical, 24)
            }
            .onChange(of: active) { _, idx in
                if let idx {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(idx, anchor: .center)
                    }
                }
            }
        }
    }
}
