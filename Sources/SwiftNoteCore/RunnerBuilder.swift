import Foundation

public struct RunnerBuilder: Sendable {
    private let cacheBaseURL: URL?

    public init(cacheBaseURL: URL? = nil) {
        self.cacheBaseURL = cacheBaseURL
    }

    public func prepare(source: String, packageContext: PackageContext?) throws -> GeneratedRunner {
        let directory = cacheDirectory(for: packageContext, source: source)
        return try prepare(source: source, in: directory, packageContext: packageContext)
    }

    public func withPreparedRunner<T>(
        source: String,
        packageContext: PackageContext?,
        body: (GeneratedRunner) throws -> T
    ) throws -> T {
        let directory = cacheDirectory(for: packageContext, source: source)
        let lockURL = directory.appendingPathComponent(".snote.lock")

        return try FileLock.withExclusiveLock(at: lockURL) {
            let runner = try prepare(source: source, in: directory, packageContext: packageContext)
            return try body(runner)
        }
    }

    private func prepare(source: String, in directory: URL, packageContext: PackageContext?) throws -> GeneratedRunner {
        if packageContext == nil {
            return try prepareStandaloneRunner(source: source, in: directory)
        }

        return try preparePackageRunner(source: source, in: directory, packageContext: packageContext)
    }

    private func prepareStandaloneRunner(source: String, in directory: URL) throws -> GeneratedRunner {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let sourceURL = directory.appendingPathComponent("RunnerEntry.swift")
        let executableURL = directory.appendingPathComponent("Runner")
        let sourceChanged = try writeIfChanged(source, to: sourceURL)
        let executableMissing = !FileManager.default.fileExists(atPath: executableURL.path)

        return GeneratedRunner(
            directory: directory,
            sourceURL: sourceURL,
            executableURL: executableURL,
            needsBuild: sourceChanged || executableMissing,
            buildStrategy: .swiftCompiler
        )
    }

    private func preparePackageRunner(source: String, in directory: URL, packageContext: PackageContext?) throws -> GeneratedRunner {
        let sourcesDirectory = directory.appendingPathComponent("Sources/Runner", isDirectory: true)
        try FileManager.default.createDirectory(at: sourcesDirectory, withIntermediateDirectories: true)

        let manifestURL = directory.appendingPathComponent("Package.swift")
        let sourceURL = sourcesDirectory.appendingPathComponent("RunnerEntry.swift")
        let executableURL = directory.appendingPathComponent(".build/debug/Runner")

        let manifestChanged = try writeIfChanged(manifest(for: packageContext), to: manifestURL)
        let sourceChanged = try writeIfChanged(source, to: sourceURL)
        let executableMissing = !FileManager.default.fileExists(atPath: executableURL.path)

        return GeneratedRunner(
            directory: directory,
            sourceURL: sourceURL,
            executableURL: executableURL,
            needsBuild: manifestChanged || sourceChanged || executableMissing,
            buildStrategy: .swiftPackage
        )
    }

    private func writeIfChanged(_ content: String, to url: URL) throws -> Bool {
        if FileManager.default.fileExists(atPath: url.path) {
            let existing = try String(contentsOf: url, encoding: .utf8)
            if existing == content {
                return false
            }
        }

        try content.write(to: url, atomically: true, encoding: .utf8)
        return true
    }

    private func cacheDirectory(for packageContext: PackageContext?, source: String) -> URL {
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

        let sourceKey = StableHash.hex("swiftc-v1\n\(source)")
        return base
            .appendingPathComponent("default", isDirectory: true)
            .appendingPathComponent("snippet-\(sourceKey)", isDirectory: true)
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
