import SwiftUI

extension VerticalAlignment {
    /// The pictures are portraits, with the face a little above the middle. The top of the picture
    /// cuts off the chin, and the middle cuts off the top of the head, so the circle takes a part
    /// between them.
    private enum ProfileFace: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d.height * 0.35 }
    }

    static var profileFace: VerticalAlignment { VerticalAlignment(ProfileFace.self) }
}

/// A round picture of a profile. With no picture, it shows the first letter of the name.
struct ProfileCircle: View {
    let name: String
    let avatar: String?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Palette.surfaceHigh)
            Text(name.prefix(1).uppercased())
                .font(Karla.font(size * 0.42, .bold))
                .foregroundStyle(Palette.textPrimary)
            if let avatar, let url = URL(string: avatar) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fill)
                    }
                }
                .frame(width: size, height: size, alignment: Alignment(horizontal: .center, vertical: .profileFace))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
    }
}

/// Puts the profiles in rows, and puts each row in the middle, as a flow row does.
struct ProfileFlowLayout: Layout {
    var spacing: CGFloat = 20
    var rowSpacing: CGFloat = 24

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = self.rows(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + rowSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let added = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if added > width, !row.indices.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
