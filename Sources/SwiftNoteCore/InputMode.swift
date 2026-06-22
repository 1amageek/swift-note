public enum InputMode: Equatable, Sendable {
    case eval(String)
    case file(String)
    case stdin(explicit: Bool)
}

