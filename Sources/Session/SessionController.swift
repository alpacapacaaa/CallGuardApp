/// 세션 시작/종료 순수 상태 머신(P4-T1). 오디오 소스(FileAudioSource 등)의 재생 시작/EOF
/// 이벤트와 수동 중지 버튼 입력을 받아 SessionState를 전이시킨다.
/// 조용한 실패 금지(AGENTS.md §5) — 정의되지 않은 전이는 명시적으로 무시(멱등 no-op)하되
/// 상태는 항상 유효한 케이스 중 하나로 남는다.
public struct SessionController: Sendable {
    public private(set) var state: SessionState = .idle
    /// F-M8 동의 상태. sourceStarted 처리 전 필수 — handle(_:) 참조.
    public private(set) var hasConsent = false

    public init() {}

    @discardableResult
    public mutating func handle(_ event: SessionEvent) -> SessionState {
        switch (state, event) {
        case (_, .consentGranted):
            hasConsent = true
        case (.idle, .sourceStarted) where hasConsent:
            state = .active
        case (.active, .sourceEnded):
            state = .ended(.endOfStream)
        case (.active, .manualStopRequested):
            state = .ended(.manualStop)
        default:
            break
        }
        return state
    }
}
