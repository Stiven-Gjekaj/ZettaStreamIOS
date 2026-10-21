import SwiftUI
import ZettaCore

/// Adds a profile, or changes the name and the picture of one. The pictures come from AniList and TVmaze.
struct EditProfileScreen: View {
    let id: String?
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var started = false
    @State private var name = ""
    @State private var avatar: String?
    @State private var search = ""
    @State private var query = ""
    @State private var loading = true
    @State private var sections: [AvatarGroup] = []
    @State private var confirmDelete = false
    @FocusState private var typing: Bool

    private var profile: Profile? { app.profiles.profiles.first { $0.id == id } }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                pickerTitle
                if loading {
                    ProgressView()
                        .tint(Palette.accent)
                        .frame(maxWidth: .infinity)
                        .padding(32)
                } else if sections.isEmpty {
                    Text(query.isEmpty ? "The pictures did not load. Check the network." : "No picture found for \"\(query)\".")
                        .font(Karla.font(15))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, settingsGutter)
                        .padding(.vertical, 24)
                }
                ForEach(sections, id: \.title) { group in
                    ProfileAvatarRow(group: group, selected: avatar) { avatar = $0 }
                }
                credit
            }
            .padding(.vertical, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .zettaScreen()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: start)
        .task(id: query) { await loadPictures() }
        .onChange(of: name) { value in
            if value.count > ProfileStore.maxName { name = String(value.prefix(ProfileStore.maxName)) }
        }
        .alert("Delete this profile?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The history, the watchlist, and the settings of this profile go.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 20) {
                ProfileCircle(name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "?" : name, avatar: avatar, size: 96)
                Text(id == nil ? "Add a profile" : "Edit profile")
                    .font(Karla.font(24, .heavy, relativeTo: .title))
            }
            TextField("", text: $name, prompt: Text("Name").foregroundColor(Palette.textSecondary))
                .focused($typing)
                .font(Karla.font(16))
                .submitLabel(.done)
                .onSubmit { typing = false }
                .modifier(ProfileFieldStyle(focused: typing))
            ProfileFlowLayout(spacing: 10, rowSpacing: 10) {
                Button("Save", action: save).buttonStyle(.zPrimary)
                Button("Cancel") { dismiss() }.buttonStyle(.zSecondary)
                if profile != nil, app.profiles.profiles.count > 1 {
                    Button("Delete profile") { confirmDelete = true }.buttonStyle(.zSecondary)
                }
                if avatar != nil {
                    Button("No picture") { avatar = nil }.buttonStyle(.zSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, settingsGutter)
    }

    private var pickerTitle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose a picture")
                .font(Karla.font(18, .semibold, relativeTo: .headline))
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.textSecondary)
                TextField("", text: $search, prompt: Text("Search a character or an actor").foregroundColor(Palette.textSecondary))
                    .font(Karla.font(16))
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit { query = search.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            .modifier(ProfileFieldStyle(focused: false))
        }
        .padding(.horizontal, settingsGutter)
        .padding(.top, 32)
        .padding(.bottom, 8)
    }

    private var credit: some View {
        Text("The pictures of anime characters come from AniList. The pictures of TV characters and actors come from TVmaze, "
            + "under CC BY-SA. The app asks these services only when you choose a picture. "
            + "The rights to each picture stay with their owners.")
            .font(Karla.font(12, relativeTo: .caption))
            .foregroundStyle(Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, settingsGutter)
            .padding(.top, 24)
    }

    /// The fields show the profile when the screen opens. Later changes of the store do not reset them.
    private func start() {
        guard !started else { return }
        started = true
        name = profile?.name ?? ""
        avatar = profile?.avatar
    }

    private func loadPictures() async {
        loading = true
        let avatars = app.container.avatars
        let text = query
        let groups = text.isEmpty ? await avatars.featured() : await avatars.search(text)
        guard !Task.isCancelled else { return }
        sections = groups
        loading = false
    }

    private func save() {
        // An ID of a profile that another screen removed adds nothing and changes nothing.
        if id != nil, profile == nil {
            dismiss()
            return
        }
        if app.saveProfile(id: id, name: name, avatar: avatar) { dismiss() }
    }

    private func delete() {
        guard let id else { return }
        if app.deleteProfile(id) { dismiss() }
    }
}

/// The dark field with a thin edge, and a white edge while the viewer types.
private struct ProfileFieldStyle: ViewModifier {
    let focused: Bool

    func body(content: Content) -> some View {
        content
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: corner))
            .overlay(RoundedRectangle(cornerRadius: corner).stroke(focused ? Palette.accent : Palette.outline))
    }
}

/// The pictures of one service in a row that scrolls to the side.
private struct ProfileAvatarRow: View {
    let group: AvatarGroup
    let selected: String?
    let choose: (String) -> Void

    private let size: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.title)
                .font(Karla.font(14, .semibold, relativeTo: .subheadline))
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, settingsGutter)
                .padding(.top, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 20) {
                    ForEach(group.avatars, id: \.url) { choice in
                        Button { choose(choice.url) } label: { tile(choice) }
                            .buttonStyle(SettingsPressStyle())
                            .accessibilityIdentifier("avatar")
                    }
                }
                .padding(.horizontal, settingsGutter)
                .padding(.vertical, 10)
            }
        }
    }

    private func tile(_ choice: Avatar) -> some View {
        let chosen = choice.url == selected
        return VStack(spacing: 8) {
            ProfileCircle(name: choice.name, avatar: choice.url, size: size)
                // The chosen picture has a thick white ring.
                .overlay(Circle().strokeBorder(Palette.accent, lineWidth: chosen ? 4 : 0))
            Text(choice.name)
                .font(Karla.font(12, relativeTo: .caption))
                .foregroundStyle(chosen ? Palette.textPrimary : Palette.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: size + 24)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}
