import SwiftUI
import ZettaCore

/// Lists each row that the addons give, so that the viewer can turn rows off and on and change their order.
struct HomeRowsScreen: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var rows: [CatalogRow] = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("Home rows")
                    .font(Karla.font(26, .heavy, relativeTo: .title))
                    .padding(.horizontal, HomeSizes.gutter(sizeClass))
                    .padding(.bottom, 4)
                Text("Tap a row to turn it off or on. The arrows on the right move a row up or down. A row that repeats a row above it does not show.")
                    .font(Karla.font(14))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, HomeSizes.gutter(sizeClass))
                    .padding(.vertical, 8)
                ForEach(Array(rows.enumerated()), id: \.element.key) { index, row in
                    HStack(spacing: 8) {
                        rowButton(row)
                        Button { move(index, step: -1) } label: { Image(systemName: "chevron.up") }
                            .buttonStyle(.zSecondary)
                            .accessibilityLabel("Move up")
                        Button { move(index, step: 1) } label: { Image(systemName: "chevron.down") }
                            .buttonStyle(.zSecondary)
                            .accessibilityLabel("Move down")
                    }
                    .padding(.horizontal, HomeSizes.gutter(sizeClass))
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: HomeRowsTrigger(addons: app.addonState, order: app.settings.rowOrder)) {
            rows = await app.homeRows()
        }
    }

    private func rowButton(_ row: CatalogRow) -> some View {
        let on = !app.settings.hiddenRows.contains(row.key)
        return Button { app.toggleHomeRow(row.key) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title + (on ? "" : "  (off)"))
                        .font(Karla.font(16, .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text("\(Display.typeLabel(row.catalog.type)) from \(row.addon.name)")
                        .font(Karla.font(14))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: corner))
            .overlay(RoundedRectangle(cornerRadius: corner).stroke(Palette.outline))
            .contentShape(Rectangle())
        }
        .buttonStyle(HomeCardButtonStyle())
        .accessibilityValue(on ? "On" : "Off")
    }

    private func move(_ index: Int, step: Int) {
        app.moveHomeRow(rows, index: index, step: step)
    }
}

/// The values that make the screen ask for its rows again.
private struct HomeRowsTrigger: Hashable {
    var addons: AddonState
    var order: [String]
}
