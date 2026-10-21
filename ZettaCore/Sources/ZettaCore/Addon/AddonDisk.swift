import Foundation

/// Keeps the manifests of the addons and the last answer of each catalog on the disk.
///
/// At the next start, Home shows its rows from these files at once, and then the answers
/// of the addons replace them. An addon that does not answer, for example with no
/// network, works with its manifest from the disk.
public final class AddonDisk: Sendable {
    /// The titles of each catalog that the disk keeps. Home shows fewer.
    public static let catalogLimit = 100

    let manifests: JSONFile<[String: JSONValue]>
    let catalogs: JSONFile<[String: [MetaPreview]]>

    public init(folder: URL) {
        manifests = JSONFile(file: folder.appendingPathComponent("manifests.json")) { [:] }
        catalogs = JSONFile(file: folder.appendingPathComponent("catalogs.json")) { [:] }
    }

    /// Keeps the manifests of the sources in the list only.
    func saveManifests(_ all: [String: JSONValue]) {
        guard all != manifests.value else { return }
        try? manifests.update { $0 = all }
    }

    /// Keeps the catalogs of the installed addons only.
    func saveCatalogs(_ all: [String: [MetaPreview]], addons: Set<String>) {
        let kept = all.filter { key, _ in addons.contains(String(key.prefix { $0 != "|" })) }
            .mapValues { Array($0.prefix(Self.catalogLimit)) }
        try? catalogs.update { $0 = kept }
    }
}
