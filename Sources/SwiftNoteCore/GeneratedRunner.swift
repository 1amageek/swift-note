import Foundation

public struct GeneratedRunner: Equatable, Sendable {
    public let directory: URL
    public let sourceURL: URL

    public init(directory: URL, sourceURL: URL) {
        self.directory = directory
        self.sourceURL = sourceURL
    }
}

