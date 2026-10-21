import SwiftUI

/// A filter chip. The chosen chip is white. The others have a thin frame.
struct LiveChip: View {
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(Karla.font(14, .medium))
                .lineLimit(1)
                .foregroundStyle(selected ? Palette.onAccent : Palette.textSecondary)
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .background(selected ? Palette.accent : Palette.surface, in: RoundedRectangle(cornerRadius: corner))
                .overlay(RoundedRectangle(cornerRadius: corner).stroke(selected ? Palette.accent : Palette.outline))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
