extension String {
    var swiftNoteStringLiteral: String {
        var result = "\""

        for scalar in unicodeScalars {
            switch scalar {
            case "\"":
                result += "\\\""
            case "\\":
                result += "\\\\"
            case "\n":
                result += "\\n"
            case "\r":
                result += "\\r"
            case "\t":
                result += "\\t"
            default:
                result.unicodeScalars.append(scalar)
            }
        }

        result += "\""
        return result
    }
}

