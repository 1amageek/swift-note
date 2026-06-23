import Foundation

public struct SwiftNoteTool: Sendable {
    public static let version = "0.1.2"

    private let argumentParser: ArgumentParser
    private let inputResolver: InputResolver
    private let instrumenter: Instrumenter
    private let packageContextResolver: PackageContextResolver
    private let runnerBuilder: RunnerBuilder
    private let runnerExecutor: RunnerExecutor
    private let reportFormatter: ReportFormatter
    private let outputWriter: StandardOutputWriter
    private let fileWatcher: FileWatcher

    public init(
        argumentParser: ArgumentParser = ArgumentParser(),
        inputResolver: InputResolver = InputResolver(),
        instrumenter: Instrumenter = Instrumenter(),
        packageContextResolver: PackageContextResolver = PackageContextResolver(),
        runnerBuilder: RunnerBuilder = RunnerBuilder(),
        runnerExecutor: RunnerExecutor = RunnerExecutor(),
        reportFormatter: ReportFormatter = ReportFormatter(),
        outputWriter: StandardOutputWriter = StandardOutputWriter(),
        fileWatcher: FileWatcher = FileWatcher()
    ) {
        self.argumentParser = argumentParser
        self.inputResolver = inputResolver
        self.instrumenter = instrumenter
        self.packageContextResolver = packageContextResolver
        self.runnerBuilder = runnerBuilder
        self.runnerExecutor = runnerExecutor
        self.reportFormatter = reportFormatter
        self.outputWriter = outputWriter
        self.fileWatcher = fileWatcher
    }

    public func run(arguments: [String]) throws -> Int32 {
        let configuration = try argumentParser.parse(arguments: arguments)

        if configuration.showHelp {
            outputWriter.write(FormattedOutput(stdout: Self.helpText, stderr: ""))
            return 0
        }

        if configuration.showVersion {
            outputWriter.write(FormattedOutput(stdout: "\(Self.version)\n", stderr: ""))
            return 0
        }

        if configuration.watch {
            return try fileWatcher.run(configuration: configuration) { watchedConfiguration in
                try runOnce(configuration: watchedConfiguration)
            }
        }

        return try runOnce(configuration: configuration)
    }

    private func runOnce(configuration: CommandConfiguration) throws -> Int32 {
        let input = try inputResolver.resolve(configuration: configuration)
        let packageContext = try packageContextResolver.resolve(packagePath: configuration.packagePath)
        let instrumentedSource = try instrumenter.instrument(input: input)
        let report = try runnerBuilder.withPreparedRunner(source: instrumentedSource, packageContext: packageContext) { runner in
            try runnerExecutor.execute(runner: runner)
        }
        let output = try reportFormatter.format(report: report, as: configuration.outputFormat)
        outputWriter.write(output)
        return report.exitCode
    }

    public static let helpText = """
    Usage:
      snote <code>
      snote -e <code>
      snote <file>
      snote --stdin

    Options:
      -e, --eval <code>       Evaluate Swift code
      -f, --file <path>       Evaluate a Swift file
          --stdin             Read Swift code from stdin
          --json              Emit JSON output
          --watch             Re-run when the input file changes
          --lines <start:end> Evaluate a file line range
          --package <path>    Use a local SwiftPM package context
          --version           Print version
      -h, --help              Print help
    """
}
