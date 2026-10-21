import SwiftUI

/// The version, the link to the code, the note on rights, the terms, and the licenses.
struct SettingsAboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showFontLicense = false

    static let repository = "https://github.com/Stiven-Gjekaj/ZettaStreamIOS"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsPageTitle(text: "About")
                    paragraph("ZettaStream \(AppInfo.version). It contains no content and no sources. "
                        + "You add your own sources, and you are responsible for them.")
                    if let url = URL(string: Self.repository) {
                        Link(destination: url) {
                            Text(Self.repository)
                                .font(Karla.font(14, .semibold))
                                .foregroundStyle(Palette.accent)
                                .underline()
                        }
                        .padding(.horizontal, settingsGutter)
                        .padding(.vertical, 6)
                    }

                    SettingsSection(title: "A note on rights")
                    paragraph("ZettaStream is a player. It contains no media and no sources, and the project does not recommend any. "
                        + "You choose your sources, and you are responsible for them and for what you watch.")

                    SettingsSection(title: "Terms")
                    ForEach(Self.terms, id: \.title) { term in
                        Text(term.title)
                            .font(Karla.font(15, .semibold))
                            .padding(.horizontal, settingsGutter)
                            .padding(.top, 10)
                        paragraph(term.text)
                    }

                    SettingsSection(title: "Licenses")
                    paragraph("The code is under the MIT License. Karla, the font of the app, is under the SIL Open Font License, Version 1.1.")
                    Button(showFontLicense ? "Hide the font license" : "Show the font license") {
                        showFontLicense.toggle()
                    }
                    .buttonStyle(.zSecondary)
                    .padding(.horizontal, settingsGutter)
                    .padding(.vertical, 8)
                    if showFontLicense {
                        Text(Self.fontLicense)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Palette.textSecondary)
                            .textSelection(.enabled)
                            .padding(.horizontal, settingsGutter)
                            .padding(.vertical, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
            }
            .zettaScreen()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Karla.font(16, .bold))
                }
            }
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(Karla.font(14, relativeTo: .subheadline))
            .foregroundStyle(Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, settingsGutter)
            .padding(.vertical, 4)
    }

    /// The text of the SIL Open Font License, from the file next to the font.
    static var fontLicense: String {
        guard let url = Bundle.main.url(forResource: "Karla-OFL", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "SIL Open Font License, Version 1.1: https://openfontlicense.org" }
        return text
    }

    /// The terms of the project, from TERMS.md of the Android app, for an app on an iPhone or an iPad.
    static let terms: [SettingsTerm] = [
        SettingsTerm("1. Licence",
         "The Software is licensed under the MIT Licence. That licence is the authoritative statement of your rights "
             + "to use, copy, change, and distribute the Software. If anything here disagrees with the licence, the licence governs."),
        SettingsTerm("2. No warranty",
         "The Software is given \"as is\", with no warranty of any kind, express or implied. This includes the warranties "
             + "of merchantability, fitness for a particular purpose, and noninfringement. You use the Software at your own risk."),
        SettingsTerm("3. Limit of liability",
         "To the largest extent that the law permits, the authors and the copyright holders are not liable for any claim, "
             + "damage, or other liability that comes from the use of the Software."),
        SettingsTerm("4. The Software contains no content",
         "The Software is a player. It contains no film, no series, no episode, no channel, and no source. It does not host, "
             + "upload, or distribute any media. The project does not publish, recommend, or keep a list of sources."),
        SettingsTerm("5. Your sources, your responsibility",
         "You choose each source that you add: each Stremio addon, each playlist, and each guide. The Software only sends "
             + "requests to the addresses that you give it, and plays what they send back. You are responsible for every source "
             + "that you add and for what you watch with it. Many works are protected by copyright. In many countries, it is "
             + "illegal to watch, download, or share a protected work without the permission of the holder of the rights. "
             + "Know the law of the country where you are, and obey it."),
        SettingsTerm("6. Torrent streams",
         "The Software can play torrent streams. A torrent connects your device to the devices of other people. Each of them "
             + "can see your IP address, and your device sends small parts of the file to them while you watch. The Software "
             + "limits the upload, but it cannot hide your IP address. It asks you to use a VPN, and it does not check that you do. "
             + "You can turn off torrent streams in the settings. You are responsible for each torrent that you open."),
        SettingsTerm("7. Services of other parties",
         "A source is a service of another party. It has its own terms, and it can stop, change, or fail at any time. The project "
             + "has no control over a source, and is not responsible for it. The Software also asks the GitHub API for the newest "
             + "release of the Software. GitHub has its own terms and its own privacy policy."),
        SettingsTerm("8. Your data",
         "The Software keeps your source list, your watchlist, and your watch history on your device only. It does not send them "
             + "to the project. It has no account, no analytics, and no advertising. The Software sends requests to the sources "
             + "that you add, and one request to the GitHub API at each start. These services can see your IP address, as any "
             + "server on the internet can."),
        SettingsTerm("9. The name of the project",
         "\"ZettaStream\" names this project. Please do not use the name in a way that suggests that this project agrees with, "
             + "or has a connection to, a changed or unofficial version, unless you have permission."),
        SettingsTerm("10. Changes to these terms",
         "These terms can change while the project grows. The copy in the default branch of the repository is the current one. "
             + "Use after a change means that you accept the new terms."),
    ]
}

/// One part of the terms, with its number and its title.
struct SettingsTerm: Hashable, Sendable {
    let title: String
    let text: String

    init(_ title: String, _ text: String) {
        self.title = title
        self.text = text
    }
}
