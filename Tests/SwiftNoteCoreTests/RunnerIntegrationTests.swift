import XCTest
@testable import SwiftNoteCore

final class RunnerIntegrationTests: XCTestCase {
    func testRunnerEvaluatesBindingsAndExpressions() throws {
        let report = try run("let a = 1\nlet b = 2\na + b")

        XCTAssertEqual(report.status, .succeeded)
        XCTAssertEqual(report.exitCode, 0)
        XCTAssertEqual(report.results.map(\.summary), ["1", "2", "3"])
        XCTAssertEqual(report.results.map(\.line), [1, 2, 3])
    }

    func testRunnerReportsCompileDiagnostics() throws {
        let report = try run("let value = missingSymbol")

        XCTAssertEqual(report.status, .failed)
        XCTAssertFalse(report.diagnostics.isEmpty)
        XCTAssertFalse(report.diagnostics[0].message.contains("swift-frontend"))
    }

    func testRunnerKeepsTopLevelBindingsVisibleToDeclarations() throws {
        let report = try run(
            """
            let base = 10
            func addBase(_ value: Int) -> Int { base + value }
            addBase(5)
            """
        )

        XCTAssertEqual(report.status, .succeeded)
        XCTAssertEqual(report.results.map(\.summary), ["10", "15"])
        XCTAssertEqual(report.results.map(\.line), [1, 3])
    }

    func testRunnerSeparatesUserStandardOutputFromReport() throws {
        let report = try run(
            """
            print("hello")
            1 + 2
            """
        )

        XCTAssertEqual(report.status, .succeeded)
        XCTAssertEqual(report.results.map(\.summary), ["()", "3"])
        XCTAssertEqual(report.results.map(\.line), [1, 2])
    }

    func testRunnerReportsThrowingBindingInitializerAtSourceLine() throws {
        let report = try run(
            """
            enum SampleError: Error { case failed }
            func fail() throws -> Int { throw SampleError.failed }
            let value = try fail()
            value + 1
            """
        )

        XCTAssertEqual(report.status, .failed)
        XCTAssertEqual(report.results.first?.kind, "error")
        XCTAssertEqual(report.results.first?.line, 3)
        XCTAssertEqual(report.diagnostics.first?.message, "failed")
    }

    private func run(_ code: String) throws -> RunReport {
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            if FileManager.default.fileExists(atPath: cacheURL.path) {
                XCTAssertNoThrow(try FileManager.default.removeItem(at: cacheURL))
            }
        }

        let instrumented = try Instrumenter().instrument(
            input: SourceInput(code: code, displayName: "<integration>")
        )
        let runner = try RunnerBuilder(cacheBaseURL: cacheURL).prepare(source: instrumented, packageContext: nil)
        return try RunnerExecutor().execute(runner: runner)
    }
}
