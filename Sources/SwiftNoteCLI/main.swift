import Darwin
import Foundation
import SwiftNoteCore

do {
    let tool = SwiftNoteTool()
    let exitCode = try tool.run(arguments: Array(CommandLine.arguments.dropFirst()))
    Darwin.exit(exitCode)
} catch let error as SwiftNoteError {
    let message = "error: \(error.description)\n"
    if let data = message.data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
    Darwin.exit(1)
} catch {
    let message = "error: \(String(describing: error))\n"
    if let data = message.data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
    Darwin.exit(1)
}

