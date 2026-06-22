import Foundation

public enum JSONValue: Equatable, Sendable, Codable, CustomStringConvertible {
    case null
    case string(String)
    case bool(Bool)
    case int(Int64)
    case uint(UInt64)
    case double(Double)
    case array([JSONValue])
    case object([String: JSONValue])

    public var description: String {
        switch self {
        case .null:
            "null"
        case .string(let value):
            value
        case .bool(let value):
            String(value)
        case .int(let value):
            String(value)
        case .uint(let value):
            String(value)
        case .double(let value):
            String(value)
        case .array(let values):
            "[" + values.map(\.description).joined(separator: ", ") + "]"
        case .object(let values):
            "{" + values.keys.sorted().map { "\($0): \(values[$0]?.description ?? "null")" }.joined(separator: ", ") + "}"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let value: Bool = Self.decode(Bool.self, from: container) {
            self = .bool(value)
            return
        }

        if let value: Int64 = Self.decode(Int64.self, from: container) {
            self = .int(value)
            return
        }

        if let value: UInt64 = Self.decode(UInt64.self, from: container) {
            self = .uint(value)
            return
        }

        if let value: Double = Self.decode(Double.self, from: container) {
            self = .double(value)
            return
        }

        if let value: String = Self.decode(String.self, from: container) {
            self = .string(value)
            return
        }

        if let value: [JSONValue] = Self.decode([JSONValue].self, from: container) {
            self = .array(value)
            return
        }

        if let value: [String: JSONValue] = Self.decode([String: JSONValue].self, from: container) {
            self = .object(value)
            return
        }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value.")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .string(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .uint(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .array(let values):
            try container.encode(values)
        case .object(let values):
            try container.encode(values)
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from container: SingleValueDecodingContainer) -> T? {
        do {
            return try container.decode(type)
        } catch {
            return nil
        }
    }
}

