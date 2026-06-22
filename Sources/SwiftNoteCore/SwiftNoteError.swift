import Foundation

public enum SwiftNoteError: Error, Equatable, CustomStringConvertible {
    case missingInput
    case conflictingInputModes
    case missingOptionValue(String)
    case unknownOption(String)
    case invalidLineRange(String)
    case fileNotFound(String)
    case unreadableInput(String)
    case packageDescribeFailed(String)
    case invalidPackageDescription
    case runnerOutputDecodingFailed(String)
    case fileLockFailed(String)

    public var description: String {
        switch self {
        case .missingInput:
            "No Swift input was provided. Use -e, --file, --stdin, or pipe code to stdin."
        case .conflictingInputModes:
            "Only one input mode can be used at a time."
        case .missingOptionValue(let option):
            "Missing value for \(option)."
        case .unknownOption(let option):
            "Unknown option: \(option)."
        case .invalidLineRange(let value):
            "Invalid line range: \(value). Use start:end with positive line numbers."
        case .fileNotFound(let path):
            "File not found: \(path)."
        case .unreadableInput(let path):
            "Input could not be read as UTF-8: \(path)."
        case .packageDescribeFailed(let message):
            "Package description failed: \(message)."
        case .invalidPackageDescription:
            "Package description JSON had an unexpected shape."
        case .runnerOutputDecodingFailed(let output):
            "Runner did not produce a valid snote report: \(output)."
        case .fileLockFailed(let message):
            "Could not acquire runner cache lock: \(message)."
        }
    }
}
