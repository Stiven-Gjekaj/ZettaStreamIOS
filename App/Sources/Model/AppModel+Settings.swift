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
