public struct RunReport: Codable, Equatable, Sendable {
    public let status: RunStatus
    public let results: [ObservationResult]
    public let diagnostics: [DiagnosticMessage]
    public let exitCode: Int32

    public init(
        status: RunStatus,
        results: [ObservationResult],
        diagnostics: [DiagnosticMessage],
        exitCode: Int32
    ) {
        self.status = status
        self.results = results
        self.diagnostics = diagnostics
        self.exitCode = exitCode
    }
}

