import SwiftUI
import ZettaCore

/// "Who is watching?", as on Netflix. The app starts here, and the settings open it again.
/// At the start, the screen is outside the tabs, so it has its own navigation for the profile editor.
struct ProfilesScreen: View {
    let startup: Bool
    @EnvironmentObject private var app: AppModel
    @State private var editPath: [ProfileEditTarget] = []

    var body: some View {
        if startup {
            NavigationStack(path: $editPath) {
                ProfilesGrid(startup: true) { id in editPath.append(ProfileEditTarget(id: id)) }
                    .navigationDestination(for: ProfileEditTarget.self) { target in
                        EditProfileScreen(id: target.id)
                    }
            }
        } else {
            ProfilesGrid(startup: false) { id in app.open(.editProfile(id)) }
        }
    }
}

/// The profile that the editor opens. A nil ID adds a profile.
private struct ProfileEditTarget: Hashable {
    let id: String?
}

private struct ProfilesGrid: View {
    let startup: Bool
    let edit: (String?) -> Void
    @EnvironmentObject private var app: AppModel
    @State private var editing = false

    private let size: CGFloat = 96

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                content.frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
        }
        .zettaScreen()
        .toolbar(startup ? .hidden : .automatic, for: .navigationBar)
    }

    /// The profiles stay in the middle of the screen when they fit, as on Android.
    private var content: some View {
        VStack(spacing: 0) {
            Text(editing ? "Edit profiles" : "Who is watching?")
                .font(Karla.font(30, .heavy, relativeTo: .largeTitle))
                .multilineTextAlignment(.center)
            ProfileFlowLayout(spacing: 20, rowSpacing: 24) {
                ForEach(app.profiles.profiles) { profile in
                    ProfileTile(label: profile.name, size: size, action: { choose(profile.id) }) {
                        ZStack {
                            ProfileCircle(name: profile.name, avatar: profile.avatar, size: size)
                            if editing {
                                Circle().fill(Palette.background.opacity(0.55))
                                Image(systemName: "pencil")
                                    .font(.system(size: size / 3, weight: .semibold))
                                    .foregroundStyle(Palette.textPrimary)
                            }
                        }
                        .accessibilityLabel(editing ? "Edit \(profile.name)" : profile.name)
                    }
                }
                if app.profiles.profiles.count < ProfileStore.maxProfiles {
                    ProfileTile(label: "Add profile", size: size, action: { edit(nil) }) {
                        ZStack {
                            Circle().stroke(Palette.outline, lineWidth: 2)
                            Image(systemName: "plus")
                                .font(.system(size: size / 3, weight: .semibold))
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                }
            }
            .padding(.vertical, 32)
            Button(editing ? "Done" : "Edit profiles") { editing.toggle() }
                .buttonStyle(.zSecondary)
        }
        .padding(24)
    }

    private func choose(_ id: String) {
        if editing {
            edit(id)
            return
        }
        // The type filter of the home screen belongs to the profile before.
        app.homeFilter = nil
        app.selectProfile(id)
    }
}

/// A round button with a name under it.
private struct ProfileTile<Picture: View>: View {
    let label: String
    let size: CGFloat
    let action: () -> Void
    @ViewBuilder let picture: () -> Picture

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                picture()
                    .frame(width: size, height: size)
                    .contentShape(Circle())
                Text(label)
                    .font(Karla.font(17))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: size + 24)
        }
        .buttonStyle(SettingsPressStyle())
    }
}
