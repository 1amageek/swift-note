public enum RuntimeSupport {
    public static let source = #"""
    private enum __SwiftNoteJSONValue: Encodable {
        case null
        case string(String)
        case bool(Bool)
        case int(Int64)
        case uint(UInt64)
        case double(Double)
        case array([__SwiftNoteJSONValue])
        case object([String: __SwiftNoteJSONValue])

        static func make(_ value: Any) -> __SwiftNoteJSONValue? {
            let mirror = Mirror(reflecting: value)

            if mirror.displayStyle == .optional {
                guard let child = mirror.children.first else {
                    return .null
                }
                return make(child.value)
            }

            switch value {
            case let value as String:
                return .string(value)
            case let value as Bool:
                return .bool(value)
            case let value as Int:
                return .int(Int64(value))
            case let value as Int8:
                return .int(Int64(value))
            case let value as Int16:
                return .int(Int64(value))
            case let value as Int32:
                return .int(Int64(value))
            case let value as Int64:
                return .int(value)
            case let value as UInt:
                return .uint(UInt64(value))
            case let value as UInt8:
                return .uint(UInt64(value))
            case let value as UInt16:
                return .uint(UInt64(value))
            case let value as UInt32:
                return .uint(UInt64(value))
            case let value as UInt64:
                return .uint(value)
            case let value as Float:
                guard value.isFinite else {
                    return .string(String(describing: value))
                }
                return .double(Double(value))
            case let value as Double:
                guard value.isFinite else {
                    return .string(String(describing: value))
                }
                return .double(value)
            default:
                break
            }

            if mirror.displayStyle == .collection || mirror.displayStyle == .set {
                return .array(mirror.children.map { child in
                    make(child.value) ?? .string(__swiftNoteSummary(child.value))
                })
            }

            if mirror.displayStyle == .dictionary {
                var object: [String: __SwiftNoteJSONValue] = [:]
                for child in mirror.children {
                    let pair = Array(Mirror(reflecting: child.value).children)
                    guard pair.count == 2 else {
                        continue
                    }
                    let key = String(describing: pair[0].value)
                    object[key] = make(pair[1].value) ?? .string(__swiftNoteSummary(pair[1].value))
                }
                return .object(object)
            }

            return nil
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()

            switch self {
            case .null:
                try container.encodeNil()
            case .string(let value):
                try container.encode(value)
            case .bool(let value):
                try container.encode(value)
            case .int(let value):
                try container.encode(value)
            case .uint(let value):
                try container.encode(value)
            case .double(let value):
                try container.encode(value)
            case .array(let values):
                try container.encode(values)
            case .object(let values):
                try container.encode(values)
            }
        }
    }

    private struct __SwiftNoteObservation: Encodable {
        let line: Int
        let kind: String
        let name: String?
        let type: String
        let value: __SwiftNoteJSONValue?
        let summary: String

        private enum CodingKeys: String, CodingKey {
            case line
            case kind
            case name
            case type
            case value
            case summary
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(line, forKey: .line)
            try container.encode(kind, forKey: .kind)
            try container.encode(name, forKey: .name)
            try container.encode(type, forKey: .type)
            try container.encode(value ?? .null, forKey: .value)
            try container.encode(summary, forKey: .summary)
        }
    }

    private struct __SwiftNoteDiagnostic: Encodable {
        let severity: String
        let message: String
    }

    private struct __SwiftNoteReport: Encodable {
        let status: String
        let results: [__SwiftNoteObservation]
        let diagnostics: [__SwiftNoteDiagnostic]
        let exitCode: Int32
    }

    private struct __SwiftNoteRuntime {
        private var results: [__SwiftNoteObservation] = []
        private var diagnostics: [__SwiftNoteDiagnostic] = []
        private var failed = false

        mutating func record<T>(line: Int, kind: String, name: String?, value: T) {
            results.append(
                __SwiftNoteObservation(
                    line: line,
                    kind: kind,
                    name: name,
                    type: __swiftNoteTypeName(value),
                    value: __SwiftNoteJSONValue.make(value),
                    summary: __swiftNoteSummary(value)
                )
            )
        }

        mutating func record(error: Error, line: Int) {
            failed = true
            let summary = String(describing: error)
            results.append(
                __SwiftNoteObservation(
                    line: line,
                    kind: "error",
                    name: nil,
                    type: __swiftNotePrettyType(String(describing: type(of: error))),
                    value: .string(summary),
                    summary: summary
                )
            )
            diagnostics.append(__SwiftNoteDiagnostic(severity: "error", message: summary))
        }

        func writeReport() -> Int32 {
            let exitCode: Int32 = failed ? 1 : 0
            let report = __SwiftNoteReport(
                status: failed ? "failed" : "succeeded",
                results: results,
                diagnostics: diagnostics,
                exitCode: exitCode
            )

            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(report)
                var outputData = data
                outputData.append(contentsOf: [10])
                if let reportPath = ProcessInfo.processInfo.environment["SWIFT_NOTE_REPORT_PATH"] {
                    try outputData.write(to: URL(fileURLWithPath: reportPath), options: .atomic)
                } else {
                    FileHandle.standardOutput.write(outputData)
                }
            } catch {
                let message = #"{"status":"failed","results":[],"diagnostics":[{"severity":"error","message":"snote could not encode its report"}],"exitCode":1}"#
                if let data = message.data(using: .utf8) {
                    var outputData = data
                    outputData.append(contentsOf: [10])
                    if ProcessInfo.processInfo.environment["SWIFT_NOTE_REPORT_PATH"] != nil {
                        FileHandle.standardError.write(outputData)
                    } else {
                        FileHandle.standardOutput.write(outputData)
                    }
                }
                return 1
            }

            return exitCode
        }
    }

    private func __swiftNoteSummary<T>(_ value: T) -> String {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional, mirror.children.isEmpty {
            return "nil"
        }
        if let string = value as? String {
            return String(reflecting: string)
        }
        if let character = value as? Character {
            return String(reflecting: String(character))
        }
        return String(describing: value)
    }

    private func __swiftNoteTypeName<T>(_ value: T) -> String {
        __swiftNotePrettyType(String(describing: type(of: value)))
    }

    private func __swiftNotePrettyType(_ typeName: String) -> String {
        let clean = typeName.replacingOccurrences(of: "Swift.", with: "")

        if clean.hasPrefix("Optional<"), clean.hasSuffix(">") {
            let inner = __swiftNoteGenericInner(clean, prefix: "Optional<")
            return __swiftNotePrettyType(inner) + "?"
        }

        if clean.hasPrefix("Array<"), clean.hasSuffix(">") {
            let inner = __swiftNoteGenericInner(clean, prefix: "Array<")
            return "[" + __swiftNotePrettyType(inner) + "]"
        }

        if clean.hasPrefix("Set<"), clean.hasSuffix(">") {
            let inner = __swiftNoteGenericInner(clean, prefix: "Set<")
            return "Set<" + __swiftNotePrettyType(inner) + ">"
        }

        if clean.hasPrefix("Dictionary<"), clean.hasSuffix(">") {
            let inner = __swiftNoteGenericInner(clean, prefix: "Dictionary<")
            let parts = __swiftNoteSplitGenericArguments(inner)
            if parts.count == 2 {
                return "[" + __swiftNotePrettyType(parts[0]) + ": " + __swiftNotePrettyType(parts[1]) + "]"
            }
        }

        return clean
    }

    private func __swiftNoteGenericInner(_ value: String, prefix: String) -> String {
        let start = value.index(value.startIndex, offsetBy: prefix.count)
        let end = value.index(before: value.endIndex)
        return String(value[start..<end])
    }

    private func __swiftNoteSplitGenericArguments(_ value: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0

        for character in value {
            if character == "<" {
                depth += 1
                current.append(character)
            } else if character == ">" {
                depth -= 1
                current.append(character)
            } else if character == ",", depth == 0 {
                parts.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(character)
            }
        }

        if !current.isEmpty {
            parts.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return parts
    }
    """#
}
