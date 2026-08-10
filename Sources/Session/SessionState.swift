/// 세션 상태 전이 입력 이벤트(P4-T1, F-M2 v2).
/// 라이브 통화 자동감지(F-C4) 대신 오디오 소스 재생 시작/종료를 세션 경계로 사용한다.
public enum SessionEvent: Sendable, Hashable {
    /// 최초 실행 시 상대방 음성 처리 고지·동의(F-M8). sourceStarted보다 먼저 처리되지 않으면
    /// 파이프라인이 시작되지 않는다 — G7 "동의 전 파이프라인 시작 코드 경로 금지"를
    /// SessionController 리듀서 자체에 구조적으로 강제한다.
    case consentGranted
    case sourceStarted
    case sourceEnded
    case manualStopRequested
}

/// 세션 종료 사유 — UI·SessionStore가 종료 경로를 구분해야 할 때 사용.
public enum SessionEndReason: Sendable, Hashable {
    case endOfStream
    case manualStop
}

public enum SessionState: Sendable, Hashable {
    case idle
    case active
    case ended(SessionEndReason)
}
