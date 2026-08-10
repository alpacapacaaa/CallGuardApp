import AlertPolicy
import Capture
import Detection
import Foundation
import STT

// P4-T6 (M1, F-S6): 전 구간(주입→경고 이벤트) 지연 측정. 픽스처 10개 × 10회 = 100 런.
// P2-T4와 동일 철학 — 전체 오디오를 청크 하나로 즉시 공급해(실시간 페이싱 생략) STT+Detection+
// AlertPolicy의 순수 처리 지연을 측정한다. 경고가 발생한 런만 표본에 포함(M1은 "발화 종료→경고").

func fail(_ message: String) -> Never {
    print("status: FAILED — \(message)")
    exit(1)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let fixturesDir = root.appendingPathComponent("Tests/Fixtures/audio")
guard let entries = try? FileManager.default.contentsOfDirectory(at: fixturesDir, includingPropertiesForKeys: nil)
else { fail("픽스처 디렉터리를 읽을 수 없음") }
let fixtures = entries.filter { $0.pathExtension == "wav" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
guard !fixtures.isEmpty else { fail("픽스처 0개") }

let cachesURL = try? FileManager.default.url(
    for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
)
guard let modelURL = cachesURL?.appendingPathComponent("CallGuard/whisper-model-cache/ggml-base.bin"),
      FileManager.default.fileExists(atPath: modelURL.path)
else { fail("base 모델 캐시 없음 — 먼저 실행: .build/debug/MeasureSTTLatency ggml-base.bin <sha256>") }
let sttSpec = WhisperModelSpec(expectedSHA256: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe")

guard let rulesData = try? Data(contentsOf: root.appendingPathComponent("rules.yaml")),
      let signature = try? String(contentsOf: root.appendingPathComponent("rules.yaml.sig"), encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines),
      let ruleEngine = try? RuleEngine.load(rulesData: rulesData, expectedSignature: signature)
else { fail("rules.yaml/.sig 로드 실패") }

let modelJSONURL = root.appendingPathComponent("ml/training/model.json")
guard FileManager.default.fileExists(atPath: modelJSONURL.path),
      let classifierModel = try? LinearClassifierModel.load(from: modelJSONURL)
else { fail("분류기 model.json 없음 — 먼저 실행: python3 ml/training/train.py --smoke") }
let classifier = LinearClassifier(model: classifierModel)

var latenciesMs: [Double] = []
var csvRows = ["fixture,pass,alerted,latency_ms"]

for pass in 0 ..< 10 {
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

        let start = Date()
        var segments = (try? transcriber.feed(
            AudioChunk(track: .remote, samples: wav.samples, sampleRate: wav.sampleRate, capturedAt: Date())
        )) ?? []
        if let residual = try? transcriber.flush() {
            segments.append(residual)
        }

        var latencyMs: Double?
        for segment in segments {
            let score = detection.evaluate(adding: segment)
            let level = policy.update(with: score)
            if level != .none, latencyMs == nil {
                latencyMs = Date().timeIntervalSince(start) * 1000
            }
        }

        if let latencyMs {
            latenciesMs.append(latencyMs)
        }
        let alerted = latencyMs != nil
        let latencyCell = latencyMs.map { String(format: "%.1f", $0) } ?? ""
        csvRows.append("\(fixture.lastPathComponent),\(pass),\(alerted),\(latencyCell)")
    }
}

func percentile(_ sorted: [Double], _ fraction: Double) -> Double {
    guard !sorted.isEmpty else { return 0 }
    let index = min(sorted.count - 1, Int((fraction * Double(sorted.count)).rounded(.up)) - 1)
    return sorted[max(0, index)]
}

let sorted = latenciesMs.sorted()
let p50 = percentile(sorted, 0.5)
let p95 = percentile(sorted, 0.95)

let csvURL = root.appendingPathComponent("e2e-latency.csv")
try? csvRows.joined(separator: "\n").write(to: csvURL, atomically: true, encoding: .utf8)

print("stage: e2e")
print("runs: \(fixtures.count * 10)")
print("alerted_samples: \(latenciesMs.count)")
print("p50_ms: \(String(format: "%.1f", p50))")
print("p95_ms: \(String(format: "%.1f", p95))")
print("csv: \(csvURL.path)")
if latenciesMs.isEmpty {
    print("status: NO_ALERTS — 경고가 한 번도 발생하지 않아 M1을 판정할 표본이 없음")
} else if p50 <= 2000, p95 <= 4000 {
    print("status: PASS — p50 ≤ 2.0s && p95 ≤ 4.0s")
} else {
    print("status: FAIL — M1 목표(p50 ≤ 2.0s && p95 ≤ 4.0s) 미달")
}
