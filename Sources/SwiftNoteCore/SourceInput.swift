public struct SourceInput: Equatable, Sendable {
    public let code: String
    public let displayName: String
    public let lineOffset: Int

    public init(code: String, displayName: String, lineOffset: Int = 0) {
        self.code = code
        self.displayName = displayName
        self.lineOffset = lineOffset
    }
}

