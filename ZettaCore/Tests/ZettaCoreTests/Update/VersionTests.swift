import Testing
@testable import ZettaCore

struct VersionTests {
    @Test func comparesEachPartAsANumber() {
        #expect(Version.isNewer("0.10.0", than: "0.9.9"))
        #expect(Version.isNewer("1.0", than: "0.9.9"))
        #expect(!Version.isNewer("0.1.0", than: "0.1.0"))
        #expect(!Version.isNewer("0.1.0", than: "0.2.0"))
        #expect(Version.compare("1.0", "1.0.0") == 0)
        #expect(Version.compare("v0.2.0", " 0.2.0 ") == 0)
    }

    @Test func aTestVersionComesBeforeTheRelease() {
        #expect(Version.isNewer("1.0.0", than: "1.0.0-rc1"))
        #expect(!Version.isNewer("1.0.0-rc1", than: "1.0.0"))
        #expect(Version.isNewer("1.0.0-rc1", than: "0.11.2"))
        #expect(Version.isNewer("1.0.0-rc10", than: "1.0.0-rc2"))
        #expect(!Version.isNewer("1.0.0-rc2", than: "1.0.0-rc2"))
        #expect(Version.isNewer("1.0.1-rc1", than: "1.0.0"))
        #expect(Version.isNewer("1.0.0-rc1", than: "1.0.0-beta3"))
    }

    @Test func aDashWithNoLabelIsTheRelease() {
        #expect(Version.compare("1.0.0-", "1.0.0") == 0)
    }
}
