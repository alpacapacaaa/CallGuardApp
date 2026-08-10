@testable import Detection
import Foundation
@testable import Onboarding
@testable import STT
import Testing

/// DoD(P4-T3): 자가 진단이 내장 샘플을 FileAudioSource로 재생해 캡처→전사→탐지→경고
/// 전 구간을 예외 없이 완주하는지 확인하는 통합 테스트. 캐시된 tiny 모델 재사용(P2-T3와 동일 경로).
struct SelfDiagnosisTests {
    private static let tinyModelSHA256 = "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21"
    private static let modelDownloadURL = URL(
        string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin"
    )!

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func cachedModel() async throws -> URL {
        let base = try FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let dir = base.appendingPathComponent("CallGuard/whisper-model-cache", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let destination = dir.appendingPathComponent("ggml-tiny.bin")
        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }
        let (tempURL, _) = try await URLSession.shared.download(from: modelDownloadURL)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    private static func ensureClassifierArtifacts() throws {
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

    @Test func selfDiagnosisPassesAllStagesForBuiltInSample() async throws {
        let sampleURL = Self.root.appendingPathComponent("Tests/Fixtures/audio/normal-delivery-01.wav")
        let modelURL = try await Self.cachedModel()
        let whisperEngine = try WhisperEngine(
            modelURL: modelURL, spec: WhisperModelSpec(expectedSHA256: Self.tinyModelSHA256)
        )

        let rulesData = try Data(contentsOf: Self.root.appendingPathComponent("rules.yaml"))
        let signature = try String(contentsOf: Self.root.appendingPathComponent("rules.yaml.sig"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let ruleEngine = try RuleEngine.load(rulesData: rulesData, expectedSignature: signature)

        try Self.ensureClassifierArtifacts()
        let classifierModel = try LinearClassifierModel.load(
            from: Self.root.appendingPathComponent("ml/training/model.json")
        )
        let classifier = LinearClassifier(model: classifierModel)

        let report = await SelfDiagnosis.run(
            sampleURL: sampleURL, whisperEngine: whisperEngine, ruleEngine: ruleEngine, classifier: classifier
        )

        #expect(report.allPassed)
        #expect(report.results.map(\.stage) == [.capture, .stt, .detection, .alertPolicy])
    }
}
