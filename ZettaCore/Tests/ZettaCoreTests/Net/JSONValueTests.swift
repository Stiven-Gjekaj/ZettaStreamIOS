import Foundation
import Testing
@testable import ZettaCore

struct JSONValueTests {
    private func parse(_ text: String) throws -> JSONValue { try JSONValue.parse(Data(text.utf8)) }

    @Test func aNumberReadsAsATextWithNoFraction() throws {
        let value = try parse(#"{"year":2020,"rating":7.4}"#)
        #expect(value["year"]?.stringValue == "2020")
        #expect(value["rating"]?.stringValue == "7.4")
    }

    @Test func aTextReadsAsANumber() throws {
        let value = try parse(#"{"season":" 2 ","episode":3}"#)
        #expect(value["season"]?.intValue == 2)
        #expect(value["episode"]?.intValue == 3)
    }

    @Test func aBooleanStaysABoolean() throws {
        let value = try parse(#"{"a":true,"b":1}"#)
        #expect(value["a"]?.boolValue == true)
        #expect(value["b"]?.boolValue == nil)
    }

    @Test func stringsLeaveOutAnObject() throws {
        let value = try parse(#"{"list":["a",{"x":1},"b"]}"#)
        #expect(value["list"]?.strings == ["a", "b"])
    }
}
