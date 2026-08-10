@testable import AlertPolicy
import Detection
import Testing

private func score(_ value: Double, _ category: RiskCategory = .threatUrgency) -> RiskScore {
    RiskScore(value: value, category: category, evidence: [])
}

struct AlertPolicyTests {
    @Test func crossesThresholdsUpward() {
        var policy = AlertPolicy()
        #expect(policy.update(with: score(0.3)) == .none)
        #expect(policy.update(with: score(0.6)) == .caution)
        #expect(policy.update(with: score(0.9)) == .danger)
    }

    /// 히스테리시스: 하강 임계가 상승 임계보다 낮아 경계값 근처 진동에도 레벨이 유지된다.
    @Test func hysteresisPreventsFlickerNearThreshold() {
        var policy = AlertPolicy()
        policy.update(with: score(0.9)) // danger
        #expect(policy.update(with: score(0.75)) == .danger) // 0.8 밑이지만 0.7 위 — 유지
        #expect(policy.update(with: score(0.65)) == .caution) // 0.7 밑 — 하강
        #expect(policy.update(with: score(0.45)) == .caution) // 0.4 위 — 유지
        #expect(policy.update(with: score(0.3)) == .none) // 0.4 밑 — 하강
    }

    @Test func nilScoreAppliesDownwardPressure() {
        var policy = AlertPolicy()
        policy.update(with: score(0.9)) // danger
        // nil = value 0 취급 — 0.4 미만이라 danger에서 바로 none으로 하강.
        #expect(policy.update(with: nil) == .none)
    }

    /// DoD: [무시] 후 세션 내 동일 카테고리 재경고 0건.
    @Test func dismissSuppressesSameCategoryReAlert() {
        var policy = AlertPolicy()
        #expect(policy.update(with: score(0.9, .threatUrgency)) == .danger)
        policy.dismiss(category: .threatUrgency)
        #expect(policy.level == .none)

        // 동일 카테고리 재경고 — 반복 고점수에도 재경고 0건.
        for _ in 0 ..< 5 {
            #expect(policy.update(with: score(0.95, .threatUrgency)) == .none)
        }
    }

    @Test func dismissDoesNotSuppressDifferentCategory() {
        var policy = AlertPolicy()
        policy.update(with: score(0.9, .threatUrgency))
        policy.dismiss(category: .threatUrgency)

        #expect(policy.update(with: score(0.9, .accountTransfer)) == .danger)
    }

    /// F-S2: dismiss 이력이 로컬 오탐 목록으로 누적된다(순서·중복 포함 보존).
    @Test func dismissalLogAccumulatesInOrder() {
        var policy = AlertPolicy()
        policy.dismiss(category: .threatUrgency)
        policy.dismiss(category: .accountTransfer)
        #expect(policy.dismissalLog == [.threatUrgency, .accountTransfer])
    }

    /// F-S3: low 프리셋은 medium 임계에서 caution이던 값에 반응하지 않는다.
    @Test func lowSensitivityRequiresHigherScoreToEscalate() {
        var lowPolicy = AlertPolicy(sensitivity: .low)
        #expect(lowPolicy.update(with: score(0.6)) == .none)
        #expect(lowPolicy.update(with: score(0.7)) == .caution)
    }
}
