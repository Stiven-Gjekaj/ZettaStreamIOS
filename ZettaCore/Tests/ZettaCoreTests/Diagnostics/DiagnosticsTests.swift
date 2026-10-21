import Foundation
import Testing
@testable import ZettaCore

struct DiagnosticsTests {
    private struct NoReader: Error, CustomStringConvertible {
        var description: String { "no reader" }
    }

    @Test func aLineHoldsTheTimeTheTagTheMessageAndTheReason() throws {
        let start = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(hour: 14, minute: 2, second: 11)))
        let diagnostics = Diagnostics(now: { start })
        diagnostics.log("player", "error at 1000", error: NoReader())
        #expect(diagnostics.allLines() == ["14:02:11 player: error at 1000 (NoReader: no reader)"])
    }

    @Test func onlyTheLastLinesStay() {
        let diagnostics = Diagnostics()
        for i in 0..<(Diagnostics.maxLines + 20) { diagnostics.log("t", "line \(i)") }
        let lines = diagnostics.allLines()
        #expect(lines.count == Diagnostics.maxLines)
        #expect(lines.first?.hasSuffix("line 20") == true)
        #expect(lines.last?.hasSuffix("line \(Diagnostics.maxLines + 19)") == true)
    }

    @Test func clearRemovesEachLine() {
        let diagnostics = Diagnostics(maxLines: 2)
        for i in 0..<3 { diagnostics.log("t", "line \(i)") }
        diagnostics.clear()
        #expect(diagnostics.allLines().isEmpty)
        diagnostics.log("t", "again")
        #expect(diagnostics.allLines().count == 1)
    }

    @Test func manyTasksCanWriteAtTheSameTime() async {
        let diagnostics = Diagnostics()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 { group.addTask { diagnostics.log("t", "line \(i)") } }
        }
        #expect(diagnostics.allLines().count == 100)
    }
}
