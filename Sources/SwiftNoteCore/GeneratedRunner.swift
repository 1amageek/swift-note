import Foundation

public struct GeneratedRunner: Equatable, Sendable {
    public let directory: URL
    public let sourceURL: URL
    public let executableURL: URL
    public let needsBuild: Bool
    public let buildStrategy: RunnerBuildStrategy

    public init(
        directory: URL,
        sourceURL: URL,
        executableURL: URL,
        needsBuild: Bool,
        buildStrategy: RunnerBuildStrategy
    ) {
        self.directory = directory
        self.sourceURL = sourceURL
        self.executableURL = executableURL
        self.needsBuild = needsBuild
        self.buildStrategy = buildStrategy
    }
}
