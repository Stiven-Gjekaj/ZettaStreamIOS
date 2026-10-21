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
