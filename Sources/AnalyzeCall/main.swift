import AlertPolicy
import CallGuardUI
import Capture
import Detection
import Foundation
import STT

// 임의의 통화 녹음 파일(WAV)을 실시간 페이싱으로 재생하며 STT→탐지→경고 파이프라인을 그대로
// 실행하는 수동 테스트 CLI. 저장소 루트에서 실행: .build/debug/AnalyzeCall <wav파일 경로>

func korean(_ level: AlertLevel) -> String {
    switch level {
    case .none: "정상"
    case .caution: "주의"
    case .danger: "위험"
    }
}

struct AnalysisContext {
    let ruleEngine: RuleEngine
    let classifier: LinearClassifier
    let modelURL: URL
    let sttSpec: WhisperModelSpec
}

func loadContext(root: URL) -> AnalysisContext? {
    let cachesURL = try? FileManager.default.url(
        for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
    )
    guard let modelURL = cachesURL?.appendingPathComponent("CallGuard/whisper-model-cache/ggml-base.bin"),
          FileManager.default.fileExists(atPath: modelURL.path)
    else {
        print("FAILED: base 모델 캐시 없음 — 먼저 실행: .build/debug/MeasureSTTLatency ggml-base.bin <sha256>")
        return nil
    }
    let sttSpec = WhisperModelSpec(expectedSHA256: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe")

    guard let rulesData = try? Data(contentsOf: root.appendingPathComponent("rules.yaml")),
          let signature = try? String(contentsOf: root.appendingPathComponent("rules.yaml.sig"), encoding: .utf8)
          .trimmingCharacters(in: .whitespacesAndNewlines),
          let ruleEngine = try? RuleEngine.load(rulesData: rulesData, expectedSignature: signature)
    else {
        print("FAILED: rules.yaml/.sig 로드 실패 — 저장소 루트에서 실행했는지 확인")
        return nil
    }

    let modelJSONURL = root.appendingPathComponent("ml/training/model.json")
    guard FileManager.default.fileExists(atPath: modelJSONURL.path),
          let classifierModel = try? LinearClassifierModel.load(from: modelJSONURL)
    else {
        print("FAILED: 분류기 model.json 없음 — 먼저 실행: python3 ml/training/train.py --smoke")
        return nil
    }

    return AnalysisContext(
        ruleEngine: ruleEngine, classifier: LinearClassifier(model: classifierModel),
        modelURL: modelURL, sttSpec: sttSpec
    )
}

func handle(
    _ segment: TranscriptSegment, detection: inout DetectionEngine, policy: inout AlertPolicy,
    report: inout SessionReportBuilder
) {
    let score = detection.evaluate(adding: segment)
    let level = policy.update(with: score)
    report.record(segment: segment, score: score, level: level)

    let timestamp = String(format: "%.1f", segment.endTime)
    print("[\(timestamp)s][\(korean(level))] \(segment.text)")
    guard let score else { return }
    let viewModel = AlertViewModel(level: level, score: score)
    if let category = viewModel.categoryLabel {
        print("  └ 유형: \(category), 위험도: \(String(format: "%.2f", score.value))")
    }
    if let action = viewModel.recommendedAction {
        print("  └ 권장 행동: \(action)")
    }
}

/// 본문을 함수로 감싸 반환 시점에 WhisperEngine이 정상 스코프 해제되게 한다 — 전역 스코프에서
/// exit()로 곧장 종료되면 whisper.cpp의 Metal 정리 코드가 잔여 residency set에서 assert
/// 크래시를 낸다(LoadTest에서 최초 발견·동일 조치).
func run(fileURL: URL) async -> Int32 {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    guard let context = loadContext(root: root) else { return 1 }

    guard let source = try? FileAudioSource(url: fileURL, track: .remote) else {
        print("FAILED: 오디오 파싱 실패 — PCM WAV 형식인지 확인(ffmpeg -i in.m4a -ar 16000 -ac 1 out.wav)")
        return 1
    }
    guard let engine = try? WhisperEngine(modelURL: context.modelURL, spec: context.sttSpec) else {
        print("FAILED: WhisperEngine 초기화 실패")
        return 1
    }

    print("재생 시작: \(fileURL.lastPathComponent) (실시간 페이싱 — 파일 길이만큼 소요됩니다)")
    print("---")

    var transcriber = TrackTranscriber(track: .remote, engine: engine)
    var detection = DetectionEngine(ruleEngine: context.ruleEngine, classifier: context.classifier)
    var policy = AlertPolicy()
    var report = SessionReportBuilder()

    do {
        for try await chunk in source.chunks() {
            for segment in try transcriber.feed(chunk) {
                handle(segment, detection: &detection, policy: &policy, report: &report)
            }
        }
        if let residual = try transcriber.flush() {
            handle(residual, detection: &detection, policy: &policy, report: &report)
        }
    } catch {
        print("FAILED: 재생/전사 실패: \(error)")
        return 1
    }

    print("---")
    print("최종 판정: \(korean(policy.level))")
    let finalReport = report.build(falsePositiveCategories: policy.dismissalLog)
    if !finalReport.evidence.isEmpty {
        print("근거 발화:")
        for line in finalReport.evidence {
            print("  - \(line.text)")
        }
    }
    return 0
}

guard CommandLine.arguments.count > 1 else {
    print("사용법: AnalyzeCall <wav파일 경로> (m4a 등은 먼저 ffmpeg -i in.m4a -ar 16000 -ac 1 out.wav 로 변환)")
    exit(64)
}

let fileURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard FileManager.default.fileExists(atPath: fileURL.path) else {
    print("FAILED: 파일 없음: \(fileURL.path)")
    exit(1)
}

let exitCode = await run(fileURL: fileURL)
exit(exitCode)
