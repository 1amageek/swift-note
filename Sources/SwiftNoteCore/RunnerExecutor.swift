import Foundation

public struct RunnerExecutor: Sendable {
    private let processExecutor: ProcessExecutor

    public init(processExecutor: ProcessExecutor = ProcessExecutor()) {
        self.processExecutor = processExecutor
    }

    public func execute(runner: GeneratedRunner) throws -> RunReport {
        if runner.needsBuild {
            let buildExecution = try build(runner: runner)
            if buildExecution.exitCode != 0 {
                return failedReport(from: buildExecution)
            }
        }

        let reportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        defer {
            if FileManager.default.fileExists(atPath: reportURL.path) {
                do {
                    try FileManager.default.removeItem(at: reportURL)
                } catch {
                    Self.writeCleanupWarning("Could not remove report file \(reportURL.path): \(error)")
                }
            }
        }

        let execution = try processExecutor.run(
            executable: runner.executableURL.path,
            arguments: [],
            environment: ["SWIFT_NOTE_REPORT_PATH": reportURL.path]
        )

        if let report = decodeReportFile(at: reportURL) ?? decodeReport(from: execution.stdout) {
            if execution.exitCode == report.exitCode {
                return report
            }
            return RunReport(
                status: report.status,
                results: report.results,
                diagnostics: report.diagnostics,
                exitCode: execution.exitCode
            )
        }

        return failedReport(from: execution)
    }

    private func build(runner: GeneratedRunner) throws -> CommandExecution {
        switch runner.buildStrategy {
        case .swiftCompiler:
            return try processExecutor.run(
                executable: "/usr/bin/env",
                arguments: [
                    "swiftc",
                    "-parse-as-library",
                    "-suppress-warnings",
                    "-o",
                    runner.executableURL.path,
                    runner.sourceURL.path,
                ]
            )
        case .swiftPackage:
            return try processExecutor.run(
                executable: "/usr/bin/env",
                arguments: ["swift", "build", "--package-path", runner.directory.path, "--product", "Runner"]
            )
        }
    }

    private func failedReport(from execution: CommandExecution) -> RunReport {
        let message = [execution.stderr, execution.stdout]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
        let sanitizedMessage = DiagnosticSanitizer.clean(message)

        return RunReport(
            status: .failed,
            results: [],
            diagnostics: [DiagnosticMessage(severity: "error", message: sanitizedMessage)],
            exitCode: execution.exitCode == 0 ? 1 : execution.exitCode
        )
    }

    private func decodeReport(from stdout: String) -> RunReport? {
        guard let data = stdout.data(using: .utf8) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(RunReport.self, from: data)
        } catch {
            return nil
        }
    }

    private func decodeReportFile(at url: URL) -> RunReport? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(RunReport.self, from: data)
        } catch {
            return nil
        }
    }

    private static func writeCleanupWarning(_ message: String) {
        guard let data = "warning: \(message)\n".data(using: .utf8) else {
            return
        }
        FileHandle.standardError.write(data)
    }
}
