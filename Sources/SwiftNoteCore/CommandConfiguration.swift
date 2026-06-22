public struct CommandConfiguration: Equatable, Sendable {
    public var inputMode: InputMode?
    public var outputFormat: OutputFormat
    public var watch: Bool
    public var lineRange: LineRange?
    public var packagePath: String?
    public var showHelp: Bool
    public var showVersion: Bool

    public init(
        inputMode: InputMode? = nil,
        outputFormat: OutputFormat = .text,
        watch: Bool = false,
        lineRange: LineRange? = nil,
        packagePath: String? = nil,
        showHelp: Bool = false,
        showVersion: Bool = false
    ) {
        self.inputMode = inputMode
        self.outputFormat = outputFormat
        self.watch = watch
        self.lineRange = lineRange
        self.packagePath = packagePath
        self.showHelp = showHelp
        self.showVersion = showVersion
    }
}

