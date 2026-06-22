import XCTest
@testable import SwiftNoteCore

final class ReportFormatterTests: XCTestCase {
    func testFormatsTextResults() throws {
        let report = RunReport(
            status: .succeeded,
            results: [
                ObservationResult(line: 1, kind: "binding", name: "a", type: "Int", value: .int(1), summary: "1"),
                ObservationResult(line: 1, kind: "expression", name: nil, type: "Int", value: .int(3), summary: "3"),
            ],
            diagnostics: [],
            exitCode: 0
        )

        let output = try ReportFormatter().format(report: report, as: .text)
        XCTAssertEqual(output.stdout, "1  a = 1\n1  3\n")
        XCTAssertEqual(output.stderr, "")
    }

    func testFormatsTextErrorResult() throws {
        let report = RunReport(
            status: .failed,
            results: [
                ObservationResult(
                    line: 3,
                    kind: "error",
                    name: nil,
                    type: "SampleError",
                    value: .string("failed"),
                    summary: "failed"
                ),
            ],
            diagnostics: [
                DiagnosticMessage(severity: "error", message: "failed"),
            ],
            exitCode: 1
        )

        let output = try ReportFormatter().format(report: report, as: .text)
        XCTAssertEqual(output.stdout, "3  error = failed\n")
        XCTAssertEqual(output.stderr, "error: failed\n")
    }

    func testFormatsNullValueInJSONResults() throws {
        let report = RunReport(
            status: .succeeded,
            results: [
                ObservationResult(
                    line: 1,
                    kind: "binding",
                    name: "box",
                    type: "Box",
                    value: nil,
                    summary: "Box()"
                ),
            ],
            diagnostics: [],
            exitCode: 0
        )

        let output = try ReportFormatter().format(report: report, as: .json)
        XCTAssertTrue(output.stdout.contains(#""value" : null"#))
    }
}
