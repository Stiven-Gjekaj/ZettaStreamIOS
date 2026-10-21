import Foundation

/// One extra argument of a catalog, for example `search` or `genre`.
public struct CatalogExtra: Hashable, Sendable {
    public let name: String
    public let isRequired: Bool
    public let options: [String]

    public init(name: String, isRequired: Bool = false, options: [String] = []) {
        self.name = name
        self.isRequired = isRequired
        self.options = options
    }
}

public struct Catalog: Hashable, Sendable {
    public let type: String
    public let id: String
    public let name: String
    public let extras: [CatalogExtra]

    public init(type: String, id: String, name: String, extras: [CatalogExtra] = []) {
        self.type = type
        self.id = id
        self.name = name
        self.extras = extras
    }

    public var supportsSearch: Bool { extras.contains { $0.name == "search" } }

    /// A catalog that needs an argument cannot show on the home screen.
    public var needsExtra: Bool { extras.contains { $0.isRequired } }
}

public struct Resource: Hashable, Sendable {
    public let name: String
    public let types: [String]?
    public let idPrefixes: [String]?

    public init(name: String, types: [String]? = nil, idPrefixes: [String]? = nil) {
        self.name = name
        self.types = types
        self.idPrefixes = idPrefixes
    }
}

public struct ManifestError: Error, Equatable {
    public let message: String
}

public struct Manifest: Hashable, Sendable {
    public let id: String
    public let name: String
    public var version: String = ""
    public var description: String = ""
    public var logo: String?
    public var types: [String] = []
    public var idPrefixes: [String]?
    public var resources: [Resource] = []
    public var catalogs: [Catalog] = []
    public var configurationRequired = false

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    /// Reads a manifest. The protocol permits two forms for a resource and
    /// for the extras of a catalog, so this reads the JSON by hand.
    public static func parse(_ root: JSONValue) throws -> Manifest {
        guard let id = root["id"]?.stringValue else { throw ManifestError(message: "The manifest has no id") }
        var manifest = Manifest(id: id, name: root["name"]?.stringValue ?? id)
        manifest.version = root["version"]?.stringValue ?? ""
        manifest.description = root["description"]?.stringValue ?? ""
        manifest.logo = root["logo"]?.stringValue
        manifest.types = root["types"]?.strings ?? []
        manifest.idPrefixes = root["idPrefixes"]?.strings
        manifest.resources = (root["resources"]?.arrayValue ?? []).compactMap(parseResource)
        manifest.catalogs = (root["catalogs"]?.arrayValue ?? []).compactMap(parseCatalog)
        manifest.configurationRequired = root["behaviorHints"]?["configurationRequired"]?.boolValue ?? false
        return manifest
    }

    private static func parseResource(_ element: JSONValue) -> Resource? {
        switch element {
        case .string(let name): return Resource(name: name)
        case .object:
            guard let name = element["name"]?.stringValue else { return nil }
            return Resource(name: name, types: element["types"]?.strings, idPrefixes: element["idPrefixes"]?.strings)
        default: return nil
        }
    }

    private static func parseCatalog(_ element: JSONValue) -> Catalog? {
        guard let type = element["type"]?.stringValue, let id = element["id"]?.stringValue else { return nil }
        let extras: [CatalogExtra]
        if let list = element["extra"]?.arrayValue {
            extras = list.compactMap { extra in
                guard let name = extra["name"]?.stringValue else { return nil }
                return CatalogExtra(
                    name: name,
                    isRequired: extra["isRequired"]?.boolValue ?? false,
                    options: extra["options"]?.strings ?? []
                )
            }
        } else {
            // The old form: two lists of names.
            let required = element["extraRequired"]?.strings ?? []
            extras = (element["extraSupported"]?.strings ?? []).map { CatalogExtra(name: $0, isRequired: required.contains($0)) }
        }
        return Catalog(type: type, id: id, name: element["name"]?.stringValue ?? id, extras: extras)
    }
}
