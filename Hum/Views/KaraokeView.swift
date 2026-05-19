import SwiftUI

func activeIndex(in lines: [LyricLine], at position: TimeInterval) -> Int? {
    guard !lines.isEmpty else { return nil }
    var lo = 0, hi = lines.count - 1, result: Int? = nil
    while lo <= hi {
        let mid = (lo + hi) / 2
        if lines[mid].timestamp <= position {
            result = mid
            lo = mid + 1
        } else {
            hi = mid - 1
        }
    }
    return result
}

struct KaraokeView: View, Equatable {
    let lines: [LyricLine]
    let active: Int?
    let fontSize: CGFloat

    static func == (lhs: KaraokeView, rhs: KaraokeView) -> Bool {
        lhs.lines == rhs.lines && lhs.active == rhs.active && lhs.fontSize == rhs.fontSize
    }

    private var lineSpacing: CGFloat { 10 }
    private var lineHeight: CGFloat { ceil(fontSize * 1.25) + lineSpacing }

    private func lineDuration(for index: Int) -> TimeInterval {
        guard index + 1 < lines.count else { return 0.9 }
        let available = lines[index + 1].timestamp - lines[index].timestamp
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
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
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
}
