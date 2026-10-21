import SwiftUI

/// The side gutter of the settings, the sources, and the profile screens on a phone.
let settingsGutter: CGFloat = 16

/// The large title at the top of a settings page.
struct SettingsPageTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Karla.font(26, .heavy, relativeTo: .largeTitle))
            .foregroundStyle(Palette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, settingsGutter)
            .padding(.bottom, 4)
    }
}

/// The small grey title above a group of settings.
struct SettingsSection: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(Karla.font(12, .semibold, relativeTo: .caption))
            .kerning(1.5)
            .foregroundStyle(Palette.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, settingsGutter)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }
}

/// The content of one setting: a title, a grey line under it, and an arrow.
struct SettingsRowLabel: View {
    let title: String
    let detail: String
    var icon = "chevron.right"

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Karla.font(16, .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(detail)
                    .font(Karla.font(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: corner))
        .overlay(RoundedRectangle(cornerRadius: corner).stroke(Palette.outline))
        .contentShape(RoundedRectangle(cornerRadius: corner))
    }
}

/// One setting that does an action when the viewer taps it.
struct SettingsRow: View {
    let title: String
    let detail: String
    var icon = "chevron.right"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowLabel(title: title, detail: detail, icon: icon)
        }
        .buttonStyle(SettingsPressStyle())
        .padding(.horizontal, settingsGutter)
        .padding(.vertical, 4)
    }
}

/// One setting with a list of choices. A tap opens the list, and a check mark shows the current choice.
struct SettingsChoiceRow<Value: Hashable>: View {
    let title: String
    let detail: String
    let options: [Value]
    let current: Value
    let label: (Value) -> String
    let choose: (Value) -> Void

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    choose(option)
                } label: {
                    if option == current {
                        Label(label(option), systemImage: "checkmark")
                    } else {
                        Text(label(option))
                    }
                }
            }
        } label: {
            SettingsRowLabel(title: title, detail: detail, icon: "chevron.up.chevron.down")
        }
        .buttonStyle(SettingsPressStyle())
        .padding(.horizontal, settingsGutter)
        .padding(.vertical, 4)
    }
}

/// One setting with a minus and a plus button, such as a delay.
struct SettingsStepperRow: View {
    let title: String
    let detail: String
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Karla.font(16, .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(detail)
                    .font(Karla.font(14, relativeTo: .subheadline))
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            stepButton("minus", "Less", decrease)
            stepButton("plus", "More", increase)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: corner))
        .overlay(RoundedRectangle(cornerRadius: corner).stroke(Palette.outline))
        .padding(.horizontal, settingsGutter)
        .padding(.vertical, 4)
    }

    private func stepButton(_ icon: String, _ name: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 40, height: 36)
                .foregroundStyle(Palette.textPrimary)
                .background(Palette.surfaceHigh, in: RoundedRectangle(cornerRadius: corner))
                .overlay(RoundedRectangle(cornerRadius: corner).stroke(Palette.outline))
        }
        .buttonStyle(SettingsPressStyle())
        .accessibilityLabel(name)
    }
}

/// A row goes a little dark while the finger is on it.
struct SettingsPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}
