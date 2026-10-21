import Foundation
import ZettaCore

extension AppModel {
    /// Adds a channel to the favourites, or removes it, and tells the viewer.
    /// `key` is the favourite key of the channel, from `Channel.favoriteKeys`.
    func toggleFavorite(_ channel: Channel, key: String) {
        let adding = !container.library.data.favoriteChannels.contains(key)
        toggleFavoriteChannel(key)
        show(adding ? "Added to the favourites: \(channel.name)" : "Removed from the favourites: \(channel.name)")
    }
}
