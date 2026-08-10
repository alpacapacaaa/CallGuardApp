import AlertPolicy
import Capture
import Detection
import Foundation
import Preprocess
import STT

// P3-T7: 픽스처 전량을 STT→Detection→AlertPolicy 전 구간으로 실행해
// (fixture,label,predicted,first_alert_time) JSONL을 stdout에 출력한다.
// ml/eval/run.py가 이 출력으로 Recall/Precision/FPR/first-alert를 산출한다.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
    exit(1)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let fixturesDir = root.appendingPathComponent("Tests/Fixtures/audio")
let dirContents = try? FileManager.default.contentsOfDirectory(at: fixturesDir, includingPropertiesForKeys: nil)
guard let entries = dirContents else { fail("픽스처 디렉터리를 읽을 수 없음") }
let fixtures = entries.filter { $0.pathExtension == "wav" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
guard !fixtures.isEmpty else { fail("픽스처 0개") }

let cachesURL = try? FileManager.default.url(
    for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
)
let modelURL = cachesURL?.appendingPathComponent("CallGuard/whisper-model-cache/ggml-base.bin")
guard let modelURL, FileManager.default.fileExists(atPath: modelURL.path) else {
    fail("base 모델 캐시 없음 — 먼저 실행: .build/debug/MeasureSTTLatency ggml-base.bin <sha256>")
}

let sttSpec = WhisperModelSpec(expectedSHA256: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe")

let rulesData = try? Data(contentsOf: root.appendingPathComponent("rules.yaml"))
let signature = try? String(contentsOf: root.appendingPathComponent("rules.yaml.sig"), encoding: .utf8)
    .trimmingCharacters(in: .whitespacesAndNewlines)
guard let rulesData, let signature else { fail("rules.yaml/.sig 읽기 실패") }
guard let ruleEngine = try? RuleEngine.load(rulesData: rulesData, expectedSignature: signature) else {
    fail("RuleEngine 로드 실패")
}

let modelJSONURL = root.appendingPathComponent("ml/training/model.json")
guard FileManager.default.fileExists(atPath: modelJSONURL.path) else {
    fail("분류기 model.json 없음 — 먼저 실행: python3 ml/training/train.py --smoke")
}

guard let classifierModel = try? LinearClassifierModel.load(from: modelJSONURL) else {
    fail("분류기 로드 실패")
}

let classifier = LinearClassifier(model: classifierModel)

for fixture in fixtures {
    guard let data = try? Data(contentsOf: fixture), let wav = try? WavFile.parse(data) else {
        fail("픽스처 파싱 실패: \(fixture.lastPathComponent)")
    }
    guard let engine = try? WhisperEngine(modelURL: modelURL, spec: sttSpec) else {
        fail("WhisperEngine 초기화 실패")
    }

    var transcriber = TrackTranscriber(track: .remote, engine: engine)
    var detection = DetectionEngine(ruleEngine: ruleEngine, classifier: classifier)
    var policy = AlertPolicy()

    var segments = (try? transcriber.feed(
        AudioChunk(track: .remote, samples: wav.samples, sampleRate: wav.sampleRate, capturedAt: Date())
    )) ?? []
    if let residual = try? transcriber.flush() {
        segments.append(residual)
    }

    var firstAlertTime: Double?
    var maxLevel = AlertLevel.none
    for segment in segments {
        let score = detection.evaluate(adding: segment)
        let level = policy.update(with: score)
        if level != .none, firstAlertTime == nil {
            firstAlertTime = segment.endTime
        }
        if level == .danger {
            maxLevel = .danger
        } else if level == .caution, maxLevel == .none {
            maxLevel = .caution
        }
    }

    let predicted = maxLevel != .none
    let firstAlertJSON = firstAlertTime.map { "\($0)" } ?? "null"
    print("""
    {"fixture":"\(fixture.lastPathComponent)","predicted_phishing":\(predicted),"first_alert_s":\(firstAlertJSON)}
    """)
}
