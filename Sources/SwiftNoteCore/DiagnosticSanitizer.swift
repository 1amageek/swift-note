public enum DiagnosticSanitizer {
    public static func clean(_ message: String) -> String {
        var lines = message.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        if let failedCommandIndex = lines.firstIndex(where: { $0.hasPrefix("Failed frontend command:") }) {
            lines = Array(lines[..<failedCommandIndex])
        }

        return lines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

