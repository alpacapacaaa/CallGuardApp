import Capture
import Detection
import Foundation
import STT
import Testing

struct RiskModelTests {
    /// PRD F-M4: 카테고리 5종 고정 — 순서·구성 변경 시 이 테스트와 PRD를 함께 봐야 한다.
    @Test func riskCategoryMatchesPrdContract() {
        #expect(RiskCategory.allCases == [
            .institutionImpersonation,
            .accountTransfer,
            .appInstallationLure,
            .personalInfoDemand,
            .threatUrgency,
        ])
    }

    /// evidence는 근거 발화 표시 순서 그대로 보존돼야 한다 (P3-T5, F-M5 근거 2–3건 노출).
    @Test func riskScoreKeepsEvidenceOrder() {
        let first = TranscriptSegment(track: .remote, text: "alpha", startTime: 1, endTime: 2, isFinal: true)
        let second = TranscriptSegment(track: .remote, text: "beta", startTime: 2, endTime: 3, isFinal: true)
        let score = RiskScore(value: 0.82, category: .institutionImpersonation, evidence: [first, second])
        #expect(score.value == 0.82)
        #expect(score.category == .institutionImpersonation)
        #expect(score.evidence.map(\.text) == ["alpha", "beta"])
    }
}
