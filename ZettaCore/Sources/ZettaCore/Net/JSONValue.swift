import Foundation

/// A JSON value of any form. Addons write the same field in different forms,
/// so the app reads their answers by hand from this type.
public enum JSONValue: Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    public static func parse(_ data: Data) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: data)
    }

    public subscript(key: String) -> JSONValue? {
        if case .object(let fields) = self { return fields[key] }
        return nil
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let fields) = self { return fields }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let items) = self { return items }
        return nil
    }

    /// A text. A number or a boolean also gives a text, because some addons
    /// write a year or an ID as a number.
    public var stringValue: String? {
        switch self {
        case .string(let text): return text
        case .number(let number):
            if number.rounded() == number, abs(number) < 1e15 { return String(Int64(number)) }
            return String(number)
        case .bool(let flag): return String(flag)
        default: return nil
        }
    }

    /// A whole number. A text that holds a number also gives it.
    public var intValue: Int? {
        switch self {
        case .number(let number) where number.rounded() == number && abs(number) < 1e15: return Int(number)
        case .string(let text): return Int(text.trimmingCharacters(in: .whitespaces))
        default: return nil
        }
    }

    public var boolValue: Bool? {
        switch self {
        case .bool(let flag): return flag
        case .string(let text): return Bool(text.lowercased())
        default: return nil
        }
    }

    /// The texts of an array. An item that is not a text is left out.
    public var strings: [String]? {
        arrayValue?.compactMap(\.stringValue)
    }
}

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let flag = try? container.decode(Bool.self) { self = .bool(flag) }
        else if let number = try? container.decode(Double.self) { self = .number(number) }
        else if let text = try? container.decode(String.self) { self = .string(text) }
        else if let items = try? container.decode([JSONValue].self) { self = .array(items) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let text): try container.encode(text)
        case .number(let number): try container.encode(number)
        case .bool(let flag): try container.encode(flag)
        case .array(let items): try container.encode(items)
        case .object(let fields): try container.encode(fields)
        case .null: try container.encodeNil()
        }
    }
}
