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

    private var active: Int? {
        activeIndex(in: lines, at: musicObserver.playbackPosition + syncOffset)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .center, spacing: 10) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line.text)
                            .font(index == active ? .title3.bold() : .callout)
                            .foregroundColor(.white)
                            .opacity(index == active ? 1.0 : 0.45)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .id(index)
                    }
                }
                .padding(.vertical, 24)
            }
            .onChange(of: active) { idx in
                if let idx {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(idx, anchor: .center)
                    }
                }
            }
        }
    }
}
