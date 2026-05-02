import SwiftUI

struct WordFlowLayout: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(0.0) { $0 + $1.height + spacing } - (rows.isEmpty ? 0 : spacing)
        return CGSize(
            width: proposal.replacingUnspecifiedDimensions().width,
            height: max(0, height)
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: ProposedViewSize(bounds.size), subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for subview in row.subviews {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: .unspecified
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var subviews: [LayoutSubview] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        let available = proposal.replacingUnspecifiedDimensions().width

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needed = current.subviews.isEmpty ? size.width : current.width + spacing + size.width

            if needed > available && !current.subviews.isEmpty {
                rows.append(current)
                current = Row(subviews: [subview], width: size.width, height: size.height)
            } else {
                current.subviews.append(subview)
                current.width = needed
                current.height = max(current.height, size.height)
            }
        }

        if !current.subviews.isEmpty { rows.append(current) }
        return rows
    }
}

struct WordFlowView: View {
    let words: [WordToken]
    let playbackPosition: TimeInterval

    var body: some View {
        WordFlowLayout(spacing: 5) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, token in
                let isLit = playbackPosition >= token.timestamp
                Text(token.text)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .opacity(isLit ? 1.0 : 0.3)
                    .animation(.spring(duration: 0.15), value: isLit)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
