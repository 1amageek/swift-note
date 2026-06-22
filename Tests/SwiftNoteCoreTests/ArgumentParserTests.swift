import XCTest
@testable import SwiftNoteCore

final class ArgumentParserTests: XCTestCase {
    func testParsesEvalJSONAndPackageOptions() throws {
        let configuration = try ArgumentParser().parse(arguments: [
            "--json",
            "--package",
            ".",
            "-e",
            "let a = 1; a + 2",
        ])

        XCTAssertEqual(configuration.outputFormat, .json)
        XCTAssertEqual(configuration.packagePath, ".")
        XCTAssertEqual(configuration.inputMode, .eval("let a = 1; a + 2"))
    }

    func testInfersExistingPositionalPathAsFile() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("swift")
        try "1 + 2".write(to: fileURL, atomically: true, encoding: .utf8)
        defer {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL))
            }
        }

        let configuration = try ArgumentParser().parse(arguments: [fileURL.path])
        XCTAssertEqual(configuration.inputMode, .file(fileURL.path))
    }

    func testRejectsConflictingInputModes() throws {
        XCTAssertThrowsError(try ArgumentParser().parse(arguments: ["--stdin", "-e", "1 + 2"])) { error in
            XCTAssertEqual(error as? SwiftNoteError, .conflictingInputModes)
        }
    }
}
