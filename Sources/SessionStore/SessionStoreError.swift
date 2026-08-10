/// SessionStore typed error (AGENTS.md §5).
public enum SessionStoreError: Error, Sendable, Equatable {
    case encryptionFailed
    case decryptionFailed
    case recordNotFound(id: String)
}
