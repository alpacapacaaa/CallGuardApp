/// STT 모듈 typed error (AGENTS.md §5).
public enum STTError: Error, Sendable, Equatable {
    case modelHashMismatch(expected: String, actual: String)
    case modelLoadFailed(path: String)
    case transcriptionFailed
}
