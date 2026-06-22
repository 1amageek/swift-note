import Foundation

public struct ProcessExecutor: Sendable {
    public init() {}

    public func run(
        executable: String,
        arguments: [String],
        workingDirectory: URL? = nil,
        environment: [String: String] = [:]
    ) throws -> CommandExecution {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let stdoutURL = directory.appendingPathComponent("stdout.txt")
        let stderrURL = directory.appendingPathComponent("stderr.txt")
        fileManager.createFile(atPath: stdoutURL.path, contents: nil)
        fileManager.createFile(atPath: stderrURL.path, contents: nil)

        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)

        defer {
            Self.close(stdoutHandle, label: "stdout capture")
            Self.close(stderrHandle, label: "stderr capture")
            Self.removeTemporaryDirectory(directory)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle
        if !environment.isEmpty {
            var mergedEnvironment = ProcessInfo.processInfo.environment
            for (key, value) in environment {
                mergedEnvironment[key] = value
            }
            process.environment = mergedEnvironment
        }
        if let workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }

        try process.run()
        process.waitUntilExit()

        try stdoutHandle.synchronize()
        try stderrHandle.synchronize()

        let stdout = try String(contentsOf: stdoutURL, encoding: .utf8)
        let stderr = try String(contentsOf: stderrURL, encoding: .utf8)
        return CommandExecution(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    private static func close(_ handle: FileHandle, label: String) {
        do {
            try handle.close()
        } catch {
            writeCleanupWarning("Could not close \(label): \(error)")
        }
    }

    private static func removeTemporaryDirectory(_ directory: URL) {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            writeCleanupWarning("Could not remove temporary directory \(directory.path): \(error)")
        }
    }

    private static func writeCleanupWarning(_ message: String) {
        guard let data = "warning: \(message)\n".data(using: .utf8) else {
            return
        }
        FileHandle.standardError.write(data)
    }
}
