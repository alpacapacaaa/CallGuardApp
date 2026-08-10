import STT

/// 피싱 위험 카테고리 — PRD F-M4의 5종 고정. 증감은 PRD 개정(운영자)과 함께만.
public enum RiskCategory: String, CaseIterable, Sendable, Hashable {
    case institutionImpersonation // 기관사칭
    case accountTransfer // 계좌송금
    case appInstallationLure // 앱설치유도
    case personalInfoDemand // 개인정보요구
    case threatUrgency // 협박·긴급성
}

/// 2단계 탐지 출력 (PRD F-M4): value 0..1 · category · evidence[].
/// AlertPolicy가 0.5(주의)/0.8(위험) 임계로 소비한다.
/// G1: evidence 전사 원문의 평문 로깅 금지.
public struct RiskScore: Sendable, Hashable {
    public let value: Double
    public let category: RiskCategory
    public let evidence: [TranscriptSegment]

    public init(value: Double, category: RiskCategory, evidence: [TranscriptSegment]) {
        self.value = value
        self.category = category
        self.evidence = evidence
    }
}
