public struct PackageContext: Equatable, Sendable {
    public let path: String
    public let packageName: String
    public let libraryProducts: [String]

    public init(path: String, packageName: String, libraryProducts: [String]) {
        self.path = path
        self.packageName = packageName
        self.libraryProducts = libraryProducts
    }
}

