import Capture
import Foundation
import STT

// P2-T4 (F-S6): 캡처→전사 구간 지연 측정. 픽스처 10개 × 2회 = 20 샘플.
// 각 청크의 latency = whisper_full() 호출 실측 시간(Preprocess는 순수 연산이라 무시 가능한 수준).

let defaultSHA256 = "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21"

func fail(_ message: String) -> Never {
    print("status: FAILED — \(message)")
    exit(1)
}

let fixturesDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Tests/Fixtures/audio")
let dirContents = try? FileManager.default.contentsOfDirectory(at: fixturesDir, includingPropertiesForKeys: nil)
guard let entries = dirContents else {
    fail("픽스처 디렉터리를 읽을 수 없음: \(fixturesDir.path)")
}

let fixtures = entries.filter { $0.pathExtension == "wav" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
guard !fixtures.isEmpty else { fail("픽스처 0개") }

let cachesURL = try? FileManager.default.url(
    for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
)
let cacheDir = cachesURL?.appendingPathComponent("CallGuard/whisper-model-cache")
let modelFileName = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ggml-tiny.bin"
guard let modelURL = cacheDir?.appendingPathComponent(modelFileName),
      FileManager.default.fileExists(atPath: modelURL.path)
else {
    fail("모델 캐시 없음 — 먼저 실행: swift test --filter WhisperEngineTests")
}

let modelSHA256 = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : defaultSHA256
let spec = WhisperModelSpec(expectedSHA256: modelSHA256)
var latenciesMs: [Double] = []
var csvRows = ["fixture,latency_ms"]

for pass in 0 ..< 2 {
    for fixture in fixtures {
        guard let data = try? Data(contentsOf: fixture), let wav = try? WavFile.parse(data) else {
            fail("픽스처 파싱 실패: \(fixture.lastPathComponent)")
        }
        guard let engine = try? WhisperEngine(modelURL: modelURL, spec: spec) else {
            fail("WhisperEngine 초기화 실패")
        }
        var transcriber = TrackTranscriber(track: .remote, engine: engine)
        let chunk = AudioChunk(track: .remote, samples: wav.samples, sampleRate: wav.sampleRate, capturedAt: Date())

        let start = Date()
        guard (try? transcriber.feed(chunk)) != nil, (try? transcriber.flush()) != nil else {
            fail("전사 실패: \(fixture.lastPathComponent)")
        }
        let latencyMs = Date().timeIntervalSince(start) * 1000
        latenciesMs.append(latencyMs)
        csvRows.append("\(fixture.lastPathComponent)-pass\(pass),\(String(format: "%.1f", latencyMs))")
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

let csvURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("stt-latency.csv")
try? csvRows.joined(separator: "\n").write(to: csvURL, atomically: true, encoding: .utf8)

print("stage: stt")
print("samples: \(latenciesMs.count)")
print("p50_ms: \(String(format: "%.1f", p50))")
print("p95_ms: \(String(format: "%.1f", p95))")
print("csv: \(csvURL.path)")
print("status: MEASURED")
