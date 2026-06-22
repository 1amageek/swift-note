import Foundation
import SwiftParser
import SwiftSyntax

public struct Instrumenter: Sendable {
    public init() {}

    public func instrument(input: SourceInput) throws -> String {
        let tree = Parser.parse(source: input.code)
        let converter = SourceLocationConverter(fileName: input.displayName, tree: tree)
        var imports: [String] = []
        var declarations: [String] = []
        var executable: [String] = []
        var openCatchLines: [Int] = []
        var expressionIndex = 0

        for item in tree.statements {
            let location = item.startLocation(converter: converter, afterLeadingTrivia: true)
            let line = location.line + input.lineOffset

            switch item.item {
            case .decl(let declaration):
                if let importDeclaration = declaration.as(ImportDeclSyntax.self) {
                    imports.append(importDeclaration.description)
                } else if let variableDeclaration = declaration.as(VariableDeclSyntax.self) {
                    let requiresLocalExecution = Self.requiresLocalExecution(variableDeclaration)
                    if requiresLocalExecution {
                        if Self.containsToken("try", inInitializersOf: variableDeclaration) {
                            executable.append("do {")
                            openCatchLines.append(line)
                        }
                        executable.append(item.description)
                    } else {
                        declarations.append(item.description)
                    }
                    for name in Self.bindingNames(in: variableDeclaration) {
                        executable.append(#"__swiftNote.record(line: \#(line), kind: "binding", name: "\#(name)", value: \#(name))"#)
                    }
                } else {
                    declarations.append(item.description)
                }
            case .expr(let expression):
                let expressionText = expression.description.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !expressionText.isEmpty else {
                    continue
                }
                let temporaryName = "__swiftNoteExpression\(expressionIndex)"
                expressionIndex += 1
                executable.append(Self.instrumentExpression(expressionText, temporaryName: temporaryName, line: line))
            case .stmt(let statement):
                executable.append(statement.description)
            }
        }

        return Self.render(
            imports: imports,
            declarations: declarations,
            executable: executable,
            openCatchLines: openCatchLines
        )
    }

    private static func bindingNames(in variableDeclaration: VariableDeclSyntax) -> [String] {
        variableDeclaration.bindings.flatMap { binding in
            bindingNames(in: binding.pattern)
        }
    }

    private static func bindingNames(in pattern: PatternSyntax) -> [String] {
        if let identifier = pattern.as(IdentifierPatternSyntax.self) {
            return [identifier.identifier.text]
        }

        if let tuple = pattern.as(TuplePatternSyntax.self) {
            return tuple.elements.flatMap { element in
                bindingNames(in: element.pattern)
            }
        }

        return []
    }

    private static func requiresLocalExecution(_ variableDeclaration: VariableDeclSyntax) -> Bool {
        containsToken("try", inInitializersOf: variableDeclaration)
            || containsToken("await", inInitializersOf: variableDeclaration)
    }

    private static func containsToken(_ token: String, inInitializersOf variableDeclaration: VariableDeclSyntax) -> Bool {
        variableDeclaration.bindings.contains { binding in
            guard let initializer = binding.initializer else {
                return false
            }
            return initializer.value.tokens(viewMode: .sourceAccurate).contains { syntaxToken in
                syntaxToken.text == token
            }
        }
    }

    private static func instrumentExpression(_ expression: String, temporaryName: String, line: Int) -> String {
        if expression.hasPrefix("try ") || expression.hasPrefix("try await ") {
            return """
            do {
                let \(temporaryName) = \(expression)
                __swiftNote.record(line: \(line), kind: "expression", name: nil, value: \(temporaryName))
            } catch {
                __swiftNote.record(error: error, line: \(line))
            }
            """
        }

        return """
        let \(temporaryName) = \(expression)
        __swiftNote.record(line: \(line), kind: "expression", name: nil, value: \(temporaryName))
        """
    }

    private static func render(
        imports: [String],
        declarations: [String],
        executable: [String],
        openCatchLines: [Int]
    ) -> String {
        let importBlock = (["import Foundation", "import Darwin"] + imports).joined(separator: "\n")
        let declarationBlock = declarations.joined(separator: "\n")
        let catchClosures = openCatchLines.reversed().map { line in
            """
            } catch {
                __swiftNote.record(error: error, line: \(line))
            }
            """
        }
        let executableBlock = (executable + catchClosures)
            .flatMap { $0.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) }
            .map { "            " + $0 }
            .joined(separator: "\n")

        return """
        \(importBlock)

        \(RuntimeSupport.source)

        \(declarationBlock)

        @main
        private struct __SwiftNoteMain {
            static func main() async {
                var __swiftNote = __SwiftNoteRuntime()
                do {
        \(executableBlock)
                    let __swiftNoteExitCode = __swiftNote.writeReport()
                    if __swiftNoteExitCode != 0 {
                        Darwin.exit(__swiftNoteExitCode)
                    }
                } catch {
                    __swiftNote.record(error: error, line: 0)
                    let __swiftNoteExitCode = __swiftNote.writeReport()
                    Darwin.exit(__swiftNoteExitCode)
                }
            }
        }
        """
    }
}
