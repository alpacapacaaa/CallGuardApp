@testable import AlertPolicy
@testable import Detection
import Foundation
import STT
import Testing

/// DoD(P4-T5): 세션 리포트(F-S1) + 오탐 피드백(F-S2) + 민감도(F-S3) Flow 시나리오 통합 테스트.
struct SessionFlowTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func ensureTrainingArtifacts() throws {
        let modelURL = root.appendingPathComponent("ml/training/model.json")
        guard !FileManager.default.fileExists(atPath: modelURL.path) else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "ml/training/train.py", "--smoke"]
        process.currentDirectoryURL = root
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    private func makeDetectionEngine() throws -> DetectionEngine {
        try Self.ensureTrainingArtifacts()
        let rulesData = try Data(contentsOf: Self.root.appendingPathComponent("rules.yaml"))
        let signature = try String(contentsOf: Self.root.appendingPathComponent("rules.yaml.sig"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let ruleEngine = try RuleEngine.load(rulesData: rulesData, expectedSignature: signature)
        let model = try LinearClassifierModel.load(from: Self.root.appendingPathComponent("ml/training/model.json"))
        return DetectionEngine(ruleEngine: ruleEngine, classifier: LinearClassifier(model: model))
    }

    /// 정상 대화 → 협박·긴급성 발화 반복 → 경보 승격 → [무시] → 재경고 억제 → 세션 종료 리포트.
    @Test func fullSessionFlowReportsTimelineAndSuppressesDismissedCategory() throws {
        var detection = try makeDetectionEngine()
        var policy = AlertPolicy(sensitivity: .medium)
        var report = SessionReportBuilder()

        let segments = [
            TranscriptSegment(track: .remote, text: "안녕하세요 고객님", startTime: 0, endTime: 2, isFinal: true),
            TranscriptSegment(
                track: .remote, text: "지금 당장 응하지 않으면 즉시 체포됩니다", startTime: 2, endTime: 4, isFinal: true
            ),
            TranscriptSegment(
                track: .remote, text: "구속영장이 발부되니 서둘러 협조하세요", startTime: 4, endTime: 6, isFinal: true
            ),
        ]

        var lastCategory: RiskCategory?
        for segment in segments {
            let score = detection.evaluate(adding: segment)
            lastCategory = score?.category ?? lastCategory
            let level = policy.update(with: score)
            report.record(segment: segment, score: score, level: level)
        }

        // 경보 카테고리로 승격됐어야 Flow의 나머지 단계(무시→억제)를 검증할 수 있다.
        let escalatedCategory = try #require(lastCategory)
        #expect(policy.level != .none)

        // F-S2: 사용자가 무시 → 세션 내 동일 카테고리 재경고 억제.
        policy.dismiss(category: escalatedCategory)
        #expect(policy.level == .none)

        let followUp = TranscriptSegment(
            track: .remote, text: "구속영장이 발부되니 서둘러 협조하세요", startTime: 6, endTime: 8, isFinal: true
        )
        let suppressedScore = detection.evaluate(adding: followUp)
        let suppressedLevel = policy.update(with: suppressedScore)
        report.record(segment: followUp, score: suppressedScore, level: suppressedLevel)
        #expect(suppressedLevel == .none)

        // F-S1: 세션 종료 후 리포트 — 타임라인 4건, 오탐 목록에 무시된 카테고리 포함.
        let finalReport = report.build(falsePositiveCategories: policy.dismissalLog)
        #expect(finalReport.timeline.count == 4)
        #expect(finalReport.falsePositiveCategories == [escalatedCategory])
        #expect(finalReport.evidence.contains { $0.text.contains("즉시 체포") })
    }

    /// F-S3: 동일 점수열이라도 민감도 프리셋에 따라 최종 레벨이 달라진다.
    @Test func sensitivityPresetChangesEscalationBehavior() {
        let score = RiskScore(value: 0.72, category: .threatUrgency, evidence: [])

        var lowPolicy = AlertPolicy(sensitivity: .low)
        var highPolicy = AlertPolicy(sensitivity: .high)
        lowPolicy.update(with: score)
        highPolicy.update(with: score)

        // low: cautionUp(0.65)만 넘어 caution에서 멈춤(dangerUp 0.90 미달).
        // high: dangerUp(0.65)까지 넘어 danger로 즉시 승격.
        #expect(lowPolicy.level == .caution)
        #expect(highPolicy.level == .danger)
    }
}
