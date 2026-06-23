import Darwin
import Foundation

public struct InputResolver: Sendable {
    public init() {}

    public func resolve(configuration: CommandConfiguration) throws -> SourceInput {
        guard let inputMode = configuration.inputMode else {
            throw SwiftNoteError.missingInput
        }

        switch inputMode {
        case .eval(let code):
            return SourceInput(code: normalizeEscapedLineBreaks(in: code), displayName: "<eval>")
        case .file(let path):
            return try resolveFile(path: path, lineRange: configuration.lineRange)
        case .stdin(let explicit):
            return try resolveStdin(explicit: explicit)
        }
    }

    private func resolveFile(path: String, lineRange: LineRange?) throws -> SourceInput {
        let absolutePath = absolutePath(for: path)
        guard FileManager.default.fileExists(atPath: absolutePath) else {
            throw SwiftNoteError.fileNotFound(path)
        }

        let code: String
        do {
            code = try String(contentsOfFile: absolutePath, encoding: .utf8)
        } catch {
            throw SwiftNoteError.unreadableInput(path)
        }

        guard let lineRange else {
            return SourceInput(code: code, displayName: absolutePath)
        }

        let lines = code.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lineRange.start <= lines.count else {
            throw SwiftNoteError.invalidLineRange("\(lineRange.start):\(lineRange.end)")
        }

        let end = min(lineRange.end, lines.count)
        let selected = lines[(lineRange.start - 1)..<end].joined(separator: "\n")
        return SourceInput(code: selected, displayName: absolutePath, lineOffset: lineRange.start - 1)
    }

    private func resolveStdin(explicit: Bool) throws -> SourceInput {
        if !explicit, isatty(STDIN_FILENO) == 1 {
            throw SwiftNoteError.missingInput
        }

        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard let code = String(data: data, encoding: .utf8) else {
            throw SwiftNoteError.unreadableInput("stdin")
        }

        return SourceInput(code: code, displayName: "<stdin>")
    }

    private func absolutePath(for path: String) -> String {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL.path
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(path)
            .standardizedFileURL
            .path
    }

    private func normalizeEscapedLineBreaks(in code: String) -> String {
        enum Mode {
            case code
            case singleLineString
            case multilineString
        }

        var output = ""
        var mode = Mode.code
        var index = code.startIndex

        while index < code.endIndex {
            switch mode {
            case .code:
                if code[index] == "\\",
                   let nextIndex = code.index(index, offsetBy: 1, limitedBy: code.endIndex),
                   nextIndex < code.endIndex,
                   code[nextIndex] == "n"
                {
                    output.append("\n")
                    index = code.index(after: nextIndex)
                } else if code[index...].hasPrefix("\"\"\"") {
                    output.append("\"\"\"")
                    index = code.index(index, offsetBy: 3)
                    mode = .multilineString
                } else if code[index] == #"""# {
                    output.append(code[index])
                    index = code.index(after: index)
                    mode = .singleLineString
                } else {
                    output.append(code[index])
                    index = code.index(after: index)
                }

            case .singleLineString:
                if code[index] == "\\" {
                    output.append(code[index])
                    let nextIndex = code.index(after: index)
                    if nextIndex < code.endIndex {
                        output.append(code[nextIndex])
                        index = code.index(after: nextIndex)
                    } else {
                        index = nextIndex
                    }
                } else if code[index] == #"""# {
                    output.append(code[index])
                    index = code.index(after: index)
                    mode = .code
                } else {
                    output.append(code[index])
                    index = code.index(after: index)
                }

            case .multilineString:
                if code[index...].hasPrefix("\"\"\"") {
                    output.append("\"\"\"")
                    index = code.index(index, offsetBy: 3)
                    mode = .code
                } else {
                    output.append(code[index])
                    index = code.index(after: index)
                }
            }
        }

        return output
    }
}
