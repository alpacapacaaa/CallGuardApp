@testable import Detection
import Foundation
import STT
import Testing

/// DoD(P3-T5): 전사 리플레이 → evidence에 실제 근거 세그먼트 포함.
struct DetectionEngineTests {
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

    private func makeEngine() throws -> DetectionEngine {
        try Self.ensureTrainingArtifacts()
        let rulesData = try Data(contentsOf: Self.root.appendingPathComponent("rules.yaml"))
        let signature = try String(contentsOf: Self.root.appendingPathComponent("rules.yaml.sig"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let ruleEngine = try RuleEngine.load(rulesData: rulesData, expectedSignature: signature)
        let model = try LinearClassifierModel.load(from: Self.root.appendingPathComponent("ml/training/model.json"))
        return DetectionEngine(ruleEngine: ruleEngine, classifier: LinearClassifier(model: model))
    }

    @Test func evidenceContainsMatchingSegmentFromReplay() throws {
        var engine = try makeEngine()

        // 전사 리플레이 시뮬레이션 — 정상 대화 뒤 협박·긴급성 룰이 매칭되는 발화.
        let segments = [
            TranscriptSegment(track: .remote, text: "안녕하세요 고객님", startTime: 0, endTime: 2, isFinal: true),
            TranscriptSegment(track: .remote, text: "오늘 날씨가 좋네요", startTime: 2, endTime: 4, isFinal: true),
            TranscriptSegment(
                track: .remote, text: "지금 당장 응하지 않으면 즉시 체포됩니다", startTime: 4, endTime: 6, isFinal: true
            ),
        ]

        var lastScore: RiskScore?
        for segment in segments {
            lastScore = engine.evaluate(adding: segment)
        }

        let score = try #require(lastScore)
        #expect(score.category == .threatUrgency)
        #expect(score.evidence.contains { $0.text.contains("즉시 체포") })
        // 무관한 초반 발화는 근거로 섞이지 않는다.
        #expect(!score.evidence.contains { $0.text == "오늘 날씨가 좋네요" })
    }

    @Test func noRuleMatchReturnsNil() throws {
        var engine = try makeEngine()
        let result = engine.evaluate(
            adding: TranscriptSegment(track: .remote, text: "안녕하세요 반갑습니다", startTime: 0, endTime: 2, isFinal: true)
        )
        #expect(result == nil)
    }
}
