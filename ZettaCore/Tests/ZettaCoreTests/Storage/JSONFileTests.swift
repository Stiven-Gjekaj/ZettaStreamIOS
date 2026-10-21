import Foundation
import Testing
@testable import ZettaCore

struct JSONFileTests {
    @Test func aChangeStaysAfterARestart() throws {
        let file = try temporaryFolder().appendingPathComponent("list.json")
        try JSONFile(file: file) { [String]() }.update { $0.append("a") }
        #expect(JSONFile(file: file) { [String]() }.value == ["a"])
    }

    @Test func aDamagedFileGivesTheFallback() throws {
        let file = try temporaryFolder().appendingPathComponent("list.json")
        try Data("{not json".utf8).write(to: file)
        #expect(JSONFile(file: file) { ["fallback"] }.value == ["fallback"])
    }

    @Test func anObserverGetsTheValueNowAndEachChange() async throws {
        let store = JSONFile(file: try temporaryFolder().appendingPathComponent("list.json")) { [String]() }
        var updates = store.updates().makeAsyncIterator()
        #expect(await updates.next() == [])
        try store.update { $0.append("a") }
        #expect(await updates.next() == ["a"])
        store.switchTo(try temporaryFolder().appendingPathComponent("list.json")) { ["other"] }
        #expect(await updates.next() == ["other"])
    }

    @Test func manyThreadsChangeTheValueAndNoChangeIsLost() async throws {
        let file = try temporaryFolder().appendingPathComponent("count.json")
        let store = JSONFile(file: file) { 0 }
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 { group.addTask { try? store.update { $0 += 1 } } }
        }
        #expect(store.value == 50)
        #expect(JSONFile(file: file) { 0 }.value == 50)
    }
}
