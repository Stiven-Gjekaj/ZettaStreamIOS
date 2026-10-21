import Foundation
import Testing
@testable import ZettaCore

func manifest(_ text: String) throws -> Manifest {
    try Manifest.parse(JSONValue.parse(Data(text.utf8)))
}

struct ManifestTests {
    @Test func readsResourcesAsNamesAndAsObjects() throws {
        let m = try manifest("""
            {"id":"a","name":"A","types":["movie","series"],"idPrefixes":["tt"],
             "resources":["catalog",{"name":"stream","types":["series"],"idPrefixes":["kitsu:"]}],
             "catalogs":[]}
            """)
        #expect(m.resources.map(\.name) == ["catalog", "stream"])
        #expect(m.resources[1].types == ["series"])
    }

    @Test func readsTheNewAndTheOldFormOfCatalogExtras() throws {
        let m = try manifest("""
            {"id":"a","name":"A","resources":[],"types":[],
             "catalogs":[
               {"type":"movie","id":"top","name":"Top","extra":[{"name":"search","isRequired":true},{"name":"genre","options":["Drama"]}]},
               {"type":"series","id":"old","extraSupported":["search","skip"],"extraRequired":["search"]}
             ]}
            """)
        let top = m.catalogs[0], old = m.catalogs[1]
        #expect(top.supportsSearch)
        #expect(top.needsExtra)
        #expect(top.extras[1].options == ["Drama"])
        #expect(old.supportsSearch)
        #expect(old.needsExtra)
        #expect(old.name == "old")
    }

    @Test func readsTheConfigurationRequiredHint() throws {
        #expect(try manifest(#"{"id":"a","behaviorHints":{"configurationRequired":true}}"#).configurationRequired)
    }

    @Test func aManifestWithNoIdIsRefused() {
        #expect(throws: ManifestError.self) { try manifest(#"{"name":"A"}"#) }
    }
}
