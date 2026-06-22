import Foundation

public struct FileWatcher: Sendable {
    public init() {}

    public func run(configuration: CommandConfiguration, execute: (CommandConfiguration) throws -> Int32) throws -> Int32 {
        guard case .file(let path) = configuration.inputMode else {
            throw SwiftNoteError.missingInput
        }

        var lastSignature = try signature(for: path)
        var lastExitCode = try execute(configuration)

        while true {
            Thread.sleep(forTimeInterval: 1.0)
            let currentSignature = try signature(for: path)
            if currentSignature != lastSignature {
                lastSignature = currentSignature
                lastExitCode = try execute(configuration)
            }
        }

        return lastExitCode
    }

    private func signature(for path: String) throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let modifiedAt = attributes[.modificationDate] as? Date
        let size = attributes[.size] as? NSNumber
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return "\(modifiedAt?.timeIntervalSince1970 ?? 0)-\(size?.int64Value ?? 0)-\(StableHash.hex(data))"
    }
}
