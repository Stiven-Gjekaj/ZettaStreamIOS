import Foundation
import Testing
@testable import ZettaCore

/// A new empty folder for one test.
func temporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

struct SafeFileTests {
    @Test func theLastWriteWins() throws {
        let file = try temporaryFolder().appendingPathComponent("settings.json")
        try Data("old".utf8).write(to: file)
        let safe = SafeFile(file: file)
        try safe.write("first")
        try safe.write("second")
        #expect(try String(contentsOf: file, encoding: .utf8) == "second")
    }

    @Test func aWriteMakesTheFolderAndLeavesNoTemporaryFile() throws {
        let folder = try temporaryFolder().appendingPathComponent("profiles/a")
        try SafeFile(file: folder.appendingPathComponent("library.json")).write("{}")
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["library.json"])
    }
}
