import Foundation

public struct PackageContextResolver: Sendable {
    private let processExecutor: ProcessExecutor

    public init(processExecutor: ProcessExecutor = ProcessExecutor()) {
        self.processExecutor = processExecutor
    }

    public func resolve(packagePath: String?) throws -> PackageContext? {
        guard let packagePath else {
            return nil
        }

        let absolutePath = absolutePath(for: packagePath)
        let execution = try processExecutor.run(
            executable: "/usr/bin/env",
            arguments: ["swift", "package", "--package-path", absolutePath, "describe", "--type", "json"]
        )

        guard execution.exitCode == 0 else {
            throw SwiftNoteError.packageDescribeFailed(execution.stderr)
        }

        guard let data = execution.stdout.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw SwiftNoteError.invalidPackageDescription
        }

        let packageName = object["identity"] as? String
            ?? URL(fileURLWithPath: absolutePath).lastPathComponent

        guard let products = object["products"] as? [[String: Any]] else {
            throw SwiftNoteError.invalidPackageDescription
        }

        let libraryProducts = products.compactMap { product -> String? in
            guard let name = product["name"] as? String,
                  let type = product["type"] as? [String: Any],
                  type["library"] != nil
            else {
                return nil
            }
            return name
        }

        return PackageContext(path: absolutePath, packageName: packageName, libraryProducts: libraryProducts)
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
