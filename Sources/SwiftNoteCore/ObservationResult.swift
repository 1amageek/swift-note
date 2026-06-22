public struct ObservationResult: Codable, Equatable, Sendable {
    public let line: Int
    public let kind: String
    public let name: String?
    public let type: String
    public let value: JSONValue?
    public let summary: String

    public init(line: Int, kind: String, name: String?, type: String, value: JSONValue?, summary: String) {
        self.line = line
        self.kind = kind
        self.name = name
        self.type = type
        self.value = value
        self.summary = summary
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(line, forKey: .line)
        try container.encode(kind, forKey: .kind)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(value ?? .null, forKey: .value)
        try container.encode(summary, forKey: .summary)
    }
}
