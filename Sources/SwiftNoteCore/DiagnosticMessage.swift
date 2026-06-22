public struct DiagnosticMessage: Codable, Equatable, Sendable {
    public let severity: String
    public let message: String

    public init(severity: String, message: String) {
        self.severity = severity
        self.message = message
    }
}

