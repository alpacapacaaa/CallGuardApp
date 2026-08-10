/// Capture 모듈 typed error (AGENTS.md §5).
/// 로그에는 원인·단계·타임스탬프만 기록 — 오디오·전사 내용 포함 금지(G1).
public enum CaptureError: Error, Sendable, Equatable {
    case fileReadFailed(path: String)
    case notWav
    case truncated
    case missingFormat
    case missingData
    case unsupportedFormat(detail: String)
    /// TCC 화면녹화 권한 거부·미부여 (SCStreamError.userDeclined). 크래시 없이 안내 상태로 전환해야 함.
    case screenCaptureDenied
    /// TCC 마이크 권한 거부·미부여 (AVAudioApplication.recordPermission). inputNode 접근 전에 차단해야 함.
    case microphoneDenied
    /// 캡처 스트림 시작·유지 실패. detail은 원인 코드·단계만 포함(G1).
    case captureFailed(detail: String)
    case wavWriteFailed(path: String)
}
