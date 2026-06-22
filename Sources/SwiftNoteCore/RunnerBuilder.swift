import Foundation

public struct RunnerBuilder: Sendable {
    private let cacheBaseURL: URL?

    public init(cacheBaseURL: URL? = nil) {
        self.cacheBaseURL = cacheBaseURL
    }

    public func prepare(source: String, packageContext: PackageContext?) throws -> GeneratedRunner {
        let directory = cacheDirectory(for: packageContext)
        return try prepare(source: source, in: directory, packageContext: packageContext)
    }

    public func withPreparedRunner<T>(
        source: String,
        packageContext: PackageContext?,
        body: (GeneratedRunner) throws -> T
    ) throws -> T {
        let directory = cacheDirectory(for: packageContext)
        let lockURL = directory.appendingPathComponent(".snote.lock")

        return try FileLock.withExclusiveLock(at: lockURL) {
            let runner = try prepare(source: source, in: directory, packageContext: packageContext)
            return try body(runner)
        }
    }

    private func prepare(source: String, in directory: URL, packageContext: PackageContext?) throws -> GeneratedRunner {
        let sourcesDirectory = directory.appendingPathComponent("Sources/Runner", isDirectory: true)
        if FileManager.default.fileExists(atPath: sourcesDirectory.path) {
            try FileManager.default.removeItem(at: sourcesDirectory)
        }
        try FileManager.default.createDirectory(at: sourcesDirectory, withIntermediateDirectories: true)

        let manifestURL = directory.appendingPathComponent("Package.swift")
        let sourceURL = sourcesDirectory.appendingPathComponent("RunnerEntry.swift")

        try manifest(for: packageContext).write(to: manifestURL, atomically: true, encoding: .utf8)
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)

        return GeneratedRunner(directory: directory, sourceURL: sourceURL)
    }

    private func cacheDirectory(for packageContext: PackageContext?) -> URL {
        let base: URL
        if let cacheBaseURL {
            base = cacheBaseURL
        } else if let configured = ProcessInfo.processInfo.environment["SNOTE_CACHE_DIR"] {
            base = URL(fileURLWithPath: configured, isDirectory: true)
        } else if let configured = ProcessInfo.processInfo.environment["SWIFT_NOTE_CACHE_DIR"] {
            base = URL(fileURLWithPath: configured, isDirectory: true)
        } else {
            base = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".snote/cache", isDirectory: true)
        }

        if let packageContext {
            return base.appendingPathComponent("package-\(StableHash.hex(packageContext.path))", isDirectory: true)
        }

        return base.appendingPathComponent("default", isDirectory: true)
    }

    private func manifest(for packageContext: PackageContext?) -> String {
        let dependencies = packageContext.map { context in
            """
            dependencies: [
                    .package(path: \(context.path.swiftNoteStringLiteral)),
                ],
            """
        } ?? "dependencies: [],"

        let targetDependencies = packageContext.map { context in
            context.libraryProducts
                .map { ".product(name: \($0.swiftNoteStringLiteral), package: \(context.packageName.swiftNoteStringLiteral))" }
                .joined(separator: ",\n                ")
        } ?? ""

        return """
        // swift-tools-version: 6.4

        import PackageDescription

        let package = Package(
            name: "SwiftNoteRunner",
            platforms: [.macOS(.v14)],
            \(dependencies)
            targets: [
                .executableTarget(
                    name: "Runner",
                    dependencies: [
                        \(targetDependencies)
                    ],
                    swiftSettings: [
                        .enableUpcomingFeature("ApproachableConcurrency"),
                    ]
                ),
            ],
            swiftLanguageModes: [.v6]
        )
        """
    }
}
