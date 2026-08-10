@testable import Detection
import Foundation
import Testing

/// DoD(P3-T4): Swift 추론이 Python(ml/training/train.py) 대비 허용 오차 내 일치 +
/// 윈도당 추론 ≤300ms. model.json·scores.json이 없으면 스모크 학습을 먼저 실행한다.
struct LinearClassifierTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func ensureArtifacts() throws {
        let modelURL = root.appendingPathComponent("ml/training/model.json")
        let scoresURL = root.appendingPathComponent("ml/training/scores.json")
        guard !FileManager.default.fileExists(atPath: modelURL.path)
            || !FileManager.default.fileExists(atPath: scoresURL.path)
        else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "ml/training/train.py", "--smoke"]
        process.currentDirectoryURL = root
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    @Test func swiftScoresMatchPythonWithinTolerance() throws {
        try Self.ensureArtifacts()
        let model = try LinearClassifierModel.load(from: Self.root.appendingPathComponent("ml/training/model.json"))
        let classifier = LinearClassifier(model: model)

        let scoresData = try Data(contentsOf: Self.root.appendingPathComponent("ml/training/scores.json"))
        let pythonScores = try JSONDecoder().decode([String: Double].self, from: scoresData)
        #expect(!pythonScores.isEmpty)

        var maxLatencyMs = 0.0
        for (text, pythonScore) in pythonScores {
            let start = Date()
            let swiftScore = classifier.score(text: text)
            maxLatencyMs = max(maxLatencyMs, Date().timeIntervalSince(start) * 1000)
            #expect(abs(swiftScore - pythonScore) < 1e-6)
        }
        // DoD: 윈도당 추론 ≤300ms.
        #expect(maxLatencyMs <= 300)
    }
}
