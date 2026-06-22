import Foundation

public struct StandardOutputWriter: Sendable {
    public init() {}

    public func write(_ output: FormattedOutput) {
        write(output.stdout, to: .standardOutput)
        write(output.stderr, to: .standardError)
    }

    private func write(_ text: String, to handle: FileHandle) {
        guard !text.isEmpty, let data = text.data(using: .utf8) else {
            return
        }
        handle.write(data)
    }
}

