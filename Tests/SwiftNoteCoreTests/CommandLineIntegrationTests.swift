import Foundation
import XCTest
@testable import SwiftNoteCore

final class CommandLineIntegrationTests: XCTestCase {
    func testCommandLineEmitsTextOutput() throws {
        let execution = try runSnote(["1", "+", "2"])

        XCTAssertEqual(execution.exitCode, 0, execution.stderr)
        XCTAssertEqual(execution.stdout, "1  3\n")
    }

    func testCommandLineTreatsEscapedLineBreakAsEvalLineBreak() throws {
        let execution = try runSnote(["-e", "let x = 10\\n x * 2"])

        XCTAssertEqual(execution.exitCode, 0, execution.stderr)
        XCTAssertEqual(execution.stdout, "1  x = 10\n2  20\n")
    }

    func testCommandLineEmitsDecodableJSONOutput() throws {
        let execution = try runSnote([
            "--json",
            "let numbers = [1, 2, 3]\nnumbers.count",
        ])

        XCTAssertEqual(execution.exitCode, 0, execution.stderr)
        let report = try decodeReport(from: execution.stdout)
        XCTAssertEqual(report.status, .succeeded)
        XCTAssertEqual(report.exitCode, 0)
        XCTAssertEqual(report.diagnostics, [])
        XCTAssertEqual(report.results.count, 2)
        XCTAssertEqual(report.results[0].line, 1)
        XCTAssertEqual(report.results[0].kind, "binding")
        XCTAssertEqual(report.results[0].name, "numbers")
        XCTAssertEqual(report.results[0].value, .array([.int(1), .int(2), .int(3)]))
        XCTAssertEqual(report.results[1].line, 2)
        XCTAssertEqual(report.results[1].kind, "expression")
        XCTAssertEqual(report.results[1].name, nil)
        XCTAssertEqual(report.results[1].value, .int(3))
    }

    func testCommandLineReadsStdinFileAndLineRange() throws {
        let stdinExecution = try runSnote(
            ["--stdin"],
            stdin: """
            let x = 10
            x * 2

            """
        )

        XCTAssertEqual(stdinExecution.exitCode, 0, stdinExecution.stderr)
        XCTAssertEqual(stdinExecution.stdout, "1  x = 10\n2  20\n")

        let directory = try temporaryDirectory(named: "file-input")
        defer { removeItemIfExists(directory) }

        let fileURL = directory.appendingPathComponent("Scratch.swift")
        try """
        let ignored = 100
        let b = 2
        b + 3
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        let fileExecution = try runSnote([fileURL.path])
        XCTAssertEqual(fileExecution.exitCode, 0, fileExecution.stderr)
        XCTAssertEqual(fileExecution.stdout, "1  ignored = 100\n2  b = 2\n3  5\n")

        let rangeExecution = try runSnote(["--lines", "2:3", fileURL.path])
        XCTAssertEqual(rangeExecution.exitCode, 0, rangeExecution.stderr)
        XCTAssertEqual(rangeExecution.stdout, "2  b = 2\n3  5\n")
    }

    func testCommandLineImportsLocalPackageContext() throws {
        let packageURL = try makeHelperPackage()
        defer { removeItemIfExists(packageURL) }

        let execution = try runSnote([
            "--package",
            packageURL.path,
            """
            import HelperLib
            makeValue()
            """,
        ])

        XCTAssertEqual(execution.exitCode, 0, execution.stderr)
        XCTAssertEqual(execution.stdout, "2  42\n")
    }

    private struct Execution {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    private enum TestCommandError: Error, CustomStringConvertible {
        case nonUTF8Output(String)
        case nonUTF8Input
        case timedOut([String])

        var description: String {
            switch self {
            case .nonUTF8Output(let stream):
                "Process produced non-UTF-8 \(stream)."
            case .nonUTF8Input:
                "stdin could not be encoded as UTF-8."
            case .timedOut(let arguments):
                "Command timed out: \(arguments.joined(separator: " "))"
            }
        }
    }

    private var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func runSnote(_ arguments: [String], stdin: String? = nil) throws -> Execution {
        let cacheURL = try temporaryDirectory(named: "cache")
        defer { removeItemIfExists(cacheURL) }
        let captureURL = try temporaryDirectory(named: "capture")
        defer { removeItemIfExists(captureURL) }

        let stdoutURL = captureURL.appendingPathComponent("stdout.txt")
        let stderrURL = captureURL.appendingPathComponent("stderr.txt")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)

        var environment = ProcessInfo.processInfo.environment
        environment["SNOTE_CACHE_DIR"] = cacheURL.path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "run", "--package-path", packageRoot.path, "snote"] + arguments
        process.currentDirectoryURL = packageRoot
        process.environment = environment
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        let stdinPipe: Pipe?
        if stdin == nil {
            stdinPipe = nil
        } else {
            let pipe = Pipe()
            process.standardInput = pipe
            stdinPipe = pipe
        }

        try process.run()

        if let stdin {
            guard let data = stdin.data(using: .utf8) else {
                throw TestCommandError.nonUTF8Input
            }
            if let stdinPipe {
                stdinPipe.fileHandleForWriting.write(data)
                try stdinPipe.fileHandleForWriting.close()
            }
        }

        let deadline = Date().addingTimeInterval(120)
        while process.isRunning {
            if Date() >= deadline {
                process.terminate()
                process.waitUntilExit()
                throw TestCommandError.timedOut(process.arguments ?? [])
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        try stdoutHandle.synchronize()
        try stderrHandle.synchronize()
        try stdoutHandle.close()
        try stderrHandle.close()

        let stdoutData = try Data(contentsOf: stdoutURL)
        let stderrData = try Data(contentsOf: stderrURL)

        guard let stdout = String(data: stdoutData, encoding: .utf8) else {
            throw TestCommandError.nonUTF8Output("stdout")
        }
        guard let stderr = String(data: stderrData, encoding: .utf8) else {
            throw TestCommandError.nonUTF8Output("stderr")
        }

        return Execution(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    private func decodeReport(from text: String) throws -> RunReport {
        guard let data = text.data(using: .utf8) else {
            throw TestCommandError.nonUTF8Output("stdout")
        }
        return try JSONDecoder().decode(RunReport.self, from: data)
    }

    private func makeHelperPackage() throws -> URL {
        let packageURL = try temporaryDirectory(named: "helper-package")
        let sourceURL = packageURL
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("HelperLib", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)

        try """
        // swift-tools-version: 6.4

        import PackageDescription

        let package = Package(
            name: "HelperPackage",
            products: [
                .library(name: "HelperLib", targets: ["HelperLib"]),
            ],
            targets: [
                .target(name: "HelperLib"),
            ]
        )
        """.write(
            to: packageURL.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        try """
        public func makeValue() -> Int {
            42
        }
        """.write(
            to: sourceURL.appendingPathComponent("HelperLib.swift"),
            atomically: true,
            encoding: .utf8
        )

        return packageURL
    }

    private func temporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("snote-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func removeItemIfExists(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            XCTFail("Could not remove temporary item \(url.path): \(error)")
        }
    }
}
