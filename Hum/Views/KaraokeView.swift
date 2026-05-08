import SwiftUI

func activeIndex(in lines: [LyricLine], at position: TimeInterval) -> Int? {
    guard !lines.isEmpty else { return nil }
    var result: Int? = nil
    for (i, line) in lines.enumerated() {
        if line.timestamp <= position { result = i } else { break }
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
                                    .opacity(0.3)
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
                            .id(index)
                        }
                    }
                    .padding(.bottom, vertPad)
                }
                .onAppear {
                    if let a = active {
                        proxy.scrollTo(a, anchor: .center)
                    }
                }
                .onChange(of: active) { newActive in
                    if let newActive {
                        withAnimation(.interpolatingSpring(stiffness: 70, damping: 12)) {
                            proxy.scrollTo(newActive, anchor: .center)
                        }
                    }
                }
            }
        }
        .clipped()
    }
}
