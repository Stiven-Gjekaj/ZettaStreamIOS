import Foundation
import ZettaCore

/// The actions of the settings, the sources, and the profile screens.
extension AppModel {
    /// Removes the progress of each video. The watchlist stays.
    func clearHistory() {
        do {
            try container.library.clearHistory()
        } catch {
            show("The history was not cleared: \(error.localizedDescription)")
        }
    }
}

extension AppModel {
    /// The text of a backup of the current profile and the source list.
    func exportBackup() -> String? {
        do {
            return try container.backup.export()
        } catch {
            show("The backup was not made: \(error.localizedDescription)")
            return nil
        }
    }

    /// Replaces the data on the device with the backup in `text`, and gives the report of the restore.
    /// When the backup changes the source list, the addons and the playlists load again.
    func restoreBackup(_ text: String) throws -> String {
        let before = container.sources.sources
        let report = try container.backup.restore(text)
        let after = container.sources.sources
        if after != before { saveSources(SourceList.format(after)) }
        return report
    }
}

extension AppModel {
    /// Adds a profile when `id` is nil, or changes the name and the picture of the profile with that ID.
    /// Gives false when the change was not saved.
    @discardableResult
    func saveProfile(id: String?, name: String, avatar: String?) -> Bool {
        do {
            if let id {
                try container.profiles.edit(id, name: name, avatar: avatar)
            } else {
                try container.profiles.add(name: name, avatar: avatar)
            }
            return true
        } catch {
            show("The profile was not saved: \(error.localizedDescription)")
            return false
        }
    }

    /// Removes a profile and its library and settings. The last profile stays.
    /// When the current profile goes, the first profile that stays opens.
    @discardableResult
    func deleteProfile(_ id: String) -> Bool {
        let current = currentProfile?.id == id
        do {
            guard try container.profiles.delete(id) else { return false }
            if current, let next = container.profiles.profiles.profiles.first {
                try container.selectProfile(next.id)
            }
            return true
        } catch {
            show("The profile was not removed: \(error.localizedDescription)")
            return false
        }
    }
}
