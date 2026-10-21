import SwiftUI
import ZettaCore

/// The options panel on the right side of the player, with the rows of the Android player.
/// The episode, the speed, and the source are not here: the controls change the episode and
/// choose another source, and the speed is always normal.
struct PlayerOptionsSheet: View {
    @ObservedObject var controller: PlayerController
    let onClose: () -> Void

    private var settings: ViewerSettings { controller.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Options")
                    .font(Karla.font(22, .bold))
                Spacer()
                Button("Done", action: onClose)
                    .buttonStyle(.zSecondary)
            }
            ScrollView {
                VStack(spacing: 8) { rows }
                    .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.black.opacity(0.88))
        .foregroundStyle(Palette.textPrimary)
    }

    @ViewBuilder
    private var rows: some View {
        trackRow("Subtitles", choices: controller.subtitleChoices, selected: controller.subtitleSelected, empty: "Off") {
            controller.selectSubtitle($0)
        }
        stepRow("Subtitle delay", value: Timing.label(controller.subtitleDelayMs)) { controller.shiftSubtitleDelay($0) }
        trackRow("Audio", choices: controller.audioChoices, selected: controller.audioSelected, empty: "One track") {
            controller.selectAudio($0)
        }
        stepRow("Audio delay", value: Timing.label(settings.audioDelayMs)) { controller.shiftAudioDelay($0) }
        choiceRow("Subtitle size", SubtitleSize.allCases, settings.subtitleSize, \.label) { value in
            controller.updateSettings { $0.subtitleSize = value }
        }
        choiceRow("Text color", SubtitleColor.allCases, settings.subtitleColor, \.label) { value in
            controller.updateSettings { $0.subtitleColor = value }
        }
        choiceRow("Background", SubtitleBackground.allCases, settings.subtitleBackground, \.label) { value in
            controller.updateSettings { $0.subtitleBackground = value }
        }
        choiceRow("Font", SubtitleFont.allCases, settings.subtitleFont, \.label) { value in
            controller.updateSettings { $0.subtitleFont = value }
        }
        choiceRow("Edge", SubtitleEdge.allCases, settings.subtitleEdge, \.label) { value in
            controller.updateSettings { $0.subtitleEdge = value }
        }
        choiceRow("Filter", VideoFilter.allCases, settings.videoFilter, { $0.label + ($0.colour ? " (more power)" : "") }) { value in
            controller.updateSettings { $0.videoFilter = value }
        }
        choiceRow("Side bars", SideBars.allCases, settings.sideBars, \.label) { value in
            controller.updateSettings { $0.sideBars = value }
        }
        if controller.isLive {
            OptionRow(label: "Channel") {
                HStack(spacing: 8) {
                    Button("Previous") { controller.changeEpisode(-1) }
                    Text("/").foregroundStyle(Palette.textSecondary)
                    Button("Next") { controller.changeEpisode(1) }
                }
            }
        }
    }

    private func trackRow(_ label: String, choices: [TrackChoice], selected: TrackChoice.Kind?, empty: String,
                          select: @escaping (TrackChoice.Kind) -> Void) -> some View {
        let current = choices.first { $0.kind == selected }?.label ?? empty
        return OptionRow(label: label) {
            if choices.count > 1 {
                Menu {
                    ForEach(choices) { choice in
                        Button { select(choice.kind) } label: {
                            if choice.kind == selected { Label(choice.label, systemImage: "checkmark") } else { Text(choice.label) }
                        }
                    }
                } label: { MenuValue(text: current) }
            } else {
                Text(current).font(Karla.font(15, .semibold))
            }
        }
    }

    private func choiceRow<T: Hashable>(_ label: String, _ options: [T], _ value: T, _ name: @escaping (T) -> String,
                                        set: @escaping (T) -> Void) -> some View {
        OptionRow(label: label) {
            Menu {
                ForEach(options, id: \.self) { option in
                    Button { set(option) } label: {
                        if option == value { Label(name(option), systemImage: "checkmark") } else { Text(name(option)) }
                    }
                }
            } label: { MenuValue(text: name(value)) }
        }
    }

    private func stepRow(_ label: String, value: String, step: @escaping (Int) -> Void) -> some View {
        OptionRow(label: label) {
            HStack(spacing: 14) {
                Button { step(-1) } label: { Image(systemName: "minus") }
                    .accessibilityLabel("Earlier")
                Text(value)
                    .font(Karla.font(15, .semibold))
                    .monospacedDigit()
                    .frame(minWidth: 64)
                Button { step(1) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Later")
            }
        }
    }
}

/// One row of the options: the name on the left, the value on the right.
private struct OptionRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            Text(label)
                .font(Karla.font(15))
                .foregroundStyle(Palette.textSecondary)
            Spacer(minLength: 12)
            content
                .font(Karla.font(15, .semibold))
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: corner))
        .overlay(RoundedRectangle(cornerRadius: corner).stroke(Palette.outline))
    }
}

private struct MenuValue: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Text(text).lineLimit(1)
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold))
        }
    }
}
