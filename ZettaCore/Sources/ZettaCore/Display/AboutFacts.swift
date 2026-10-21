import Foundation

extension Display {
    /// The facts for the About table, as label and value. A fact that the addon does not give does not show.
    public static func aboutFacts(_ m: Meta) -> [(label: String, value: String)] {
        let preview = m.preview
        let seasons = Set(m.videos.compactMap(\.season).filter { $0 > 0 }).count
        let directors = people(m.director, limit: 3)
        let cast = people(m.cast)
        let otherNames = preview.aliases.filter { $0 != preview.name }.prefix(2)
        let facts: [(String, String)?] = [
            kind(m.type).map { ("Type", $0) },
            preview.releaseInfo.map { ("Released", $0) },
            m.runtime.map { ("Runtime", $0) },
            rating(preview.imdbRating).map { ("IMDb", "\($0) / 10") },
            preview.genres.isEmpty ? nil : ("Genres", preview.genres.joined(separator: ", ")),
            directors.isEmpty ? nil : ("Director", directors.joined(separator: ", ")),
            cast.isEmpty ? nil : ("Cast", cast.joined(separator: ", ")),
            seasons > 0 && m.type != "movie" ? ("Seasons", String(seasons)) : nil,
            !m.videos.isEmpty && m.type != "movie" ? ("Episodes", String(m.videos.count)) : nil,
            otherNames.isEmpty ? nil : ("Other names", otherNames.joined(separator: ", ")),
        ]
        return facts.compactMap { $0.map { (label: $0.0, value: $0.1) } }
    }
}
