public struct LineRange: Equatable, Sendable {
    public let start: Int
    public let end: Int

    public init(start: Int, end: Int) throws {
        guard start > 0, end >= start else {
            throw SwiftNoteError.invalidLineRange("\(start):\(end)")
        }
        self.start = start
        self.end = end
    }

    public static func parse(_ value: String) throws -> LineRange {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let start = Int(parts[0]),
              let end = Int(parts[1])
        else {
            throw SwiftNoteError.invalidLineRange(value)
        }
        return try LineRange(start: start, end: end)
    }
}

