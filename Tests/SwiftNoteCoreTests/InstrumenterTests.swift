import XCTest
@testable import SwiftNoteCore

final class InstrumenterTests: XCTestCase {
    func testInstrumentsBindingsAndExpressions() throws {
        let source = try Instrumenter().instrument(
            input: SourceInput(code: "let a = 1\nlet b = 2\na + b", displayName: "<test>")
        )

        XCTAssertTrue(source.contains(#"__swiftNote.record(line: 1, kind: "binding", name: "a", value: a)"#))
        XCTAssertTrue(source.contains(#"__swiftNote.record(line: 2, kind: "binding", name: "b", value: b)"#))
        XCTAssertTrue(source.contains(#"__swiftNote.record(line: 3, kind: "expression", name: nil"#))
        XCTAssertTrue(source.contains("@main"))
    }

    func testKeepsDeclarationsOutsideEntryPoint() throws {
        let source = try Instrumenter().instrument(
            input: SourceInput(code: "func double(_ x: Int) -> Int { x * 2 }\ndouble(3)", displayName: "<test>")
        )

        guard let declarationRange = source.range(of: "func double") else {
            XCTFail("Expected declaration in generated source.")
            return
        }
        guard let entryPointRange = source.range(of: "@main") else {
            XCTFail("Expected generated entry point.")
            return
        }
        XCTAssertLessThan(declarationRange.lowerBound, entryPointRange.lowerBound)
    }
}

