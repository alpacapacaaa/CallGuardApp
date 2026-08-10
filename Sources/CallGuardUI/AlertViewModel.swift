import AlertPolicy
import Detection

/// 경고 UI 표시 상태(P4-T2, F-M5). SwiftUI에 의존하지 않는 순수 값 타입 — 뷰모델 테스트 대상.
public struct AlertViewModel: Sendable, Equatable {
    public let level: AlertLevel
    public let categoryLabel: String?
    /// 근거 발화 2–3건.
    public let evidenceLines: [String]
    public let recommendedAction: String?

    public init(level: AlertLevel, score: RiskScore?) {
        self.level = level
        categoryLabel = score.map { Self.label(for: $0.category) }
        evidenceLines = Array((score?.evidence ?? []).prefix(3).map(\.text))
        recommendedAction = level == .danger
            ? "즉시 전화를 끊고 해당 기관 공식 대표번호로 직접 재확인하세요."
            : nil
    }

    private static func label(for category: RiskCategory) -> String {
        switch category {
        case .institutionImpersonation: "기관사칭"
        case .accountTransfer: "계좌송금"
        case .appInstallationLure: "앱설치유도"
        case .personalInfoDemand: "개인정보요구"
        case .threatUrgency: "협박·긴급성"
        }
    }
}
