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
            return SourceInput(code: code, displayName: "<eval>")
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
}

