import Foundation

public struct ArgumentParser: Sendable {
    public init() {}

    public func parse(arguments: [String]) throws -> CommandConfiguration {
        var configuration = CommandConfiguration()
        var positionals: [String] = []
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]

            switch argument {
            case "--help", "-h":
                configuration.showHelp = true
            case "--version":
                configuration.showVersion = true
            case "--":
                index += 1
                while index < arguments.count {
                    positionals.append(arguments[index])
                    index += 1
                }
                continue
            case "--json":
                configuration.outputFormat = .json
            case "--watch":
                configuration.watch = true
            case "--stdin":
                try setInputMode(.stdin(explicit: true), on: &configuration)
            case "--eval", "-e":
                index += 1
                guard index < arguments.count else {
                    throw SwiftNoteError.missingOptionValue(argument)
                }
                try setInputMode(.eval(arguments[index]), on: &configuration)
            case "--file", "-f":
                index += 1
                guard index < arguments.count else {
                    throw SwiftNoteError.missingOptionValue(argument)
                }
                try setInputMode(.file(arguments[index]), on: &configuration)
            case "--lines":
                index += 1
                guard index < arguments.count else {
                    throw SwiftNoteError.missingOptionValue(argument)
                }
                configuration.lineRange = try LineRange.parse(arguments[index])
            case "--package":
                index += 1
                guard index < arguments.count else {
                    throw SwiftNoteError.missingOptionValue(argument)
                }
                configuration.packagePath = arguments[index]
            default:
                if argument.hasPrefix("-") {
                    throw SwiftNoteError.unknownOption(argument)
                }
                positionals.append(argument)
            }

            index += 1
        }

        if configuration.inputMode != nil, !positionals.isEmpty {
            throw SwiftNoteError.conflictingInputModes
        }

        if configuration.inputMode == nil, !positionals.isEmpty {
            configuration.inputMode = inferInputMode(from: positionals)
        }

        if configuration.inputMode == nil, !configuration.showHelp, !configuration.showVersion {
            configuration.inputMode = .stdin(explicit: false)
        }

        return configuration
    }

    private func setInputMode(_ inputMode: InputMode, on configuration: inout CommandConfiguration) throws {
        guard configuration.inputMode == nil else {
            throw SwiftNoteError.conflictingInputModes
        }
        configuration.inputMode = inputMode
    }

    private func inferInputMode(from positionals: [String]) -> InputMode {
        if positionals.count == 1, FileManager.default.fileExists(atPath: positionals[0]) {
            return .file(positionals[0])
        }
        return .eval(positionals.joined(separator: " "))
    }
}
