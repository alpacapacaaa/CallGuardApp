/// Capture 모듈 typed error (AGENTS.md §5).
/// 로그에는 원인·단계·타임스탬프만 기록 — 오디오·전사 내용 포함 금지(G1).
public enum CaptureError: Error, Sendable, Equatable {
    case fileReadFailed(path: String)
    case notWav
    case truncated
    case missingFormat
    case missingData
    case unsupportedFormat(detail: String)
}
