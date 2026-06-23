import XCTest
@testable import SwiftNoteCore

final class InputResolverTests: XCTestCase {
    func testNormalizesEscapedLineBreaksInEvalInput() throws {
        let configuration = CommandConfiguration(inputMode: .eval("let x = 10\\nx * 2"))

        let input = try InputResolver().resolve(configuration: configuration)

        XCTAssertEqual(input.code, "let x = 10\nx * 2")
    }

    func testKeepsEscapedLineBreaksInsideStringLiterals() throws {
        let configuration = CommandConfiguration(inputMode: .eval(#"let text = "\n"\ntext.count"#))

        let input = try InputResolver().resolve(configuration: configuration)

        XCTAssertEqual(input.code, #"let text = "\n""# + "\ntext.count")
    }

    func testReadsSelectedFileLinesWithOriginalLineOffset() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("swift")
        try """
        let a = 1
        let b = 2
        a + b
        """.write(to: fileURL, atomically: true, encoding: .utf8)
        defer {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                XCTAssertNoThrow(try FileManager.default.removeItem(at: fileURL))
            }
        }

        let configuration = CommandConfiguration(
            inputMode: .file(fileURL.path),
            lineRange: try LineRange(start: 2, end: 3)
        )

        let input = try InputResolver().resolve(configuration: configuration)
        XCTAssertEqual(input.code, "let b = 2\na + b")
        XCTAssertEqual(input.lineOffset, 1)
    }
}
