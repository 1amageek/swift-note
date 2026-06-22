import Foundation

public struct ReportFormatter: Sendable {
    public init() {}

    public func format(report: RunReport, as outputFormat: OutputFormat) throws -> FormattedOutput {
        switch outputFormat {
        case .json:
            return try formatJSON(report: report)
        case .text:
            return formatText(report: report)
        }
    }

    private func formatJSON(report: RunReport) throws -> FormattedOutput {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(report)
        guard let text = String(data: data, encoding: .utf8) else {
            throw SwiftNoteError.runnerOutputDecodingFailed("<encoded report>")
        }
        return FormattedOutput(stdout: text + "\n", stderr: "")
    }

    private func formatText(report: RunReport) -> FormattedOutput {
        let output = report.results.map(formatResult).joined(separator: "\n")
        let diagnostics = report.diagnostics.map { "\($0.severity): \($0.message)" }.joined(separator: "\n")

        return FormattedOutput(
            stdout: output.isEmpty ? "" : output + "\n",
            stderr: diagnostics.isEmpty ? "" : diagnostics + "\n"
        )
    }

    private func formatResult(_ result: ObservationResult) -> String {
        let prefix = "\(result.line)  "

        if let name = result.name {
            return "\(prefix)\(name) = \(result.summary)"
        }

        if result.kind == "error" {
            return "\(prefix)error = \(result.summary)"
        }

        return "\(prefix)\(result.summary)"
    }
}
