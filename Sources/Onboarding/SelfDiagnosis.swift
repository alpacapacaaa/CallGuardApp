import AlertPolicy
import Capture
import Detection
import Foundation
import STT

/// 온보딩 자가 진단(F-M6, P4-T3). 내장 샘플을 FileAudioSource로 프로덕션과 동일한
/// 실시간 페이싱 경로로 재생해 캡처→전사→탐지→경고 전 구간이 예외 없이 완주하는지 확인한다.
public enum DiagnosisStage: String, Sendable, CaseIterable {
    case capture
    case stt
    case detection
    case alertPolicy
}

public struct DiagnosisResult: Sendable, Equatable {
    public let stage: DiagnosisStage
    public let passed: Bool
    public let detail: String
}

public struct SelfDiagnosisReport: Sendable {
    public let results: [DiagnosisResult]
    public var allPassed: Bool {
        results.allSatisfy(\.passed)
    }
}

public enum SelfDiagnosis {
    /// sampleURL: 내장 픽스처 WAV. FileAudioSource 계약대로 재생하므로 실제 소요 시간만큼 걸린다.
    public static func run(
        sampleURL: URL,
        whisperEngine: WhisperEngine,
        ruleEngine: RuleEngine,
        classifier: LinearClassifier
    ) async -> SelfDiagnosisReport {
        var results: [DiagnosisResult] = []

        let source: FileAudioSource
        do {
            source = try FileAudioSource(url: sampleURL, track: .remote)
        } catch {
            results.append(DiagnosisResult(stage: .capture, passed: false, detail: "샘플 로드 실패: \(error)"))
            return SelfDiagnosisReport(results: results)
        }

        var transcriber = TrackTranscriber(track: .remote, engine: whisperEngine)
        var segments: [TranscriptSegment] = []
        do {
            for try await chunk in source.chunks() {
                try segments.append(contentsOf: transcriber.feed(chunk))
            }
            if let residual = try transcriber.flush() {
                segments.append(residual)
            }
            results.append(DiagnosisResult(stage: .capture, passed: true, detail: "청크 수신·전사 위임 완료"))
        } catch {
            results.append(DiagnosisResult(stage: .capture, passed: false, detail: "\(error)"))
            return SelfDiagnosisReport(results: results)
        }

        let sttPassed = !segments.isEmpty && segments.contains { !$0.text.isEmpty }
        results.append(DiagnosisResult(
            stage: .stt, passed: sttPassed, detail: sttPassed ? "\(segments.count)개 구간 전사" : "전사 결과 없음"
        ))
        guard sttPassed else { return SelfDiagnosisReport(results: results) }

        var detection = DetectionEngine(ruleEngine: ruleEngine, classifier: classifier)
        var policy = AlertPolicy()
        for segment in segments {
            let score = detection.evaluate(adding: segment)
            policy.update(with: score)
        }
        results.append(DiagnosisResult(
            stage: .detection, passed: true, detail: "\(segments.count)개 구간 평가 완료"
        ))
        results.append(DiagnosisResult(
            stage: .alertPolicy, passed: true, detail: "최종 레벨=\(policy.level)"
        ))

        return SelfDiagnosisReport(results: results)
    }
}
