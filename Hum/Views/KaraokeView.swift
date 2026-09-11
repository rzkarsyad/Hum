import SwiftUI

struct KaraokeView: View, Equatable {
    let items: [KaraokeItem]
    let active: Int?
    let fontSize: CGFloat
    let musicObserver: MusicObserver

    // Equality intentionally excludes musicObserver: the dots subview observes it
    // directly, so KaraokeView's body only re-evaluates on structural changes.
    static func == (lhs: KaraokeView, rhs: KaraokeView) -> Bool {
        lhs.items == rhs.items && lhs.active == rhs.active && lhs.fontSize == rhs.fontSize
    }

    private var lineSpacing: CGFloat { 10 }
    private var lineHeight: CGFloat { ceil(fontSize * 1.25) + lineSpacing }

    /// Duration of the active-line appearance animation: time until the next item
    /// begins. For a line before an instrumental gap, the next item is that gap, so
    /// this is the line's natural duration (not the full gap) — fixing the pacing bug.
    private func lineDuration(for index: Int) -> TimeInterval {
        guard index + 1 < items.count else { return 0.9 }
        let available = items[index + 1].start - items[index].start
        return max(available, 0.3)
    }

    private func lineOpacity(for index: Int) -> Double {
        guard let active else { return 0.2 }
        switch abs(index - active) {
        case 0: return 0.3
        case 1: return 0.45
        case 2: return 0.28
        default: return 0.15
        }
    }

    private func lineScale(for index: Int) -> CGFloat {
        index == active ? 1.0 : 0.96
    }

    var body: some View {
        GeometryReader { geo in
            let vertPad = max(0, geo.size.height / 2 - lineHeight / 2)
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: lineSpacing) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            itemView(index: index, item: item)
                                .padding(.horizontal, 16)
                                .scaleEffect(lineScale(for: index), anchor: .leading)
                                .animation(.spring(duration: 0.45, bounce: 0.1), value: active)
                                .id(index)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, vertPad)
                }
                .onAppear {
                    if let a = active {
                        proxy.scrollTo(a, anchor: .center)
                    }
                }
                .onChange(of: active) { _, newActive in
                    if let newActive {
                        withAnimation(.spring(duration: 0.55, bounce: 0.12)) {
                            proxy.scrollTo(newActive, anchor: .center)
                        }
                    }
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.1),
                            .init(color: .black, location: 0.88),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
    }

    @ViewBuilder
    private func itemView(index: Int, item: KaraokeItem) -> some View {
        switch item {
        case .lyric(let line):
            ZStack(alignment: .leading) {
                Text(line.text)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(lineOpacity(for: index))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if index == active {
                    Text(line.text)
                        .customAttribute(EmphasisAttribute())
                        .font(.system(size: fontSize, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.asymmetric(
                            insertion: AnyTransition(TextTransition(duration: lineDuration(for: index))),
                            removal: .opacity.animation(.easeOut(duration: 0.15))
                        ))
                }
            }
        case .instrumental(let start, let end):
            Group {
                if index == active {
                    InstrumentalDotsView(start: start, end: end, fontSize: fontSize, clock: musicObserver)
                } else {
                    DotsRow(fills: [0, 0, 0], fontSize: fontSize)
                        .opacity(lineOpacity(for: index))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
