import Foundation
import ZettaCore

extension AppModel {
    /// Puts a search at the top of the recent searches of the profile.
    func addSearchHistory(_ query: String) {
        updateSettings { $0.searchHistory = SearchHistory.add($0.searchHistory, query) }
    }

    /// Removes all recent searches of the profile.
    func clearSearchHistory() {
        updateSettings { $0.searchHistory = [] }
    }
}
