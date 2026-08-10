import Capture
import Foundation
import Preprocess
import STT

// P2-T5: 픽스처 전체를 wide(원본)·narrow8k(통화 대역 시뮬레이션) 두 대역으로 전사해
// JSONL로 stdout에 출력한다. ml/eval/cer.py가 이 출력을 소비한다.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
    exit(1)
}

func jsonString(_ value: String) -> String {
    let data = (try? JSONEncoder().encode(value)) ?? Data()
    return String(data: data, encoding: .utf8) ?? "\"\""
}

func transcribe(samples: [Float], sampleRate: Int, modelURL: URL, spec: WhisperModelSpec) -> String {
    guard let engine = try? WhisperEngine(modelURL: modelURL, spec: spec) else { return "" }
    var pipeline = PreprocessPipeline(track: .remote)
    let chunk = AudioChunk(track: .remote, samples: samples, sampleRate: sampleRate, capturedAt: Date())
    var text = ""
    for preprocessed in pipeline.feed(chunk) {
        text += (try? engine.transcribe(samples: preprocessed.samples)) ?? ""
    }
    if let residual = pipeline.flush() {
        text += (try? engine.transcribe(samples: residual.samples)) ?? ""
    }
    return text
}

let fixturesDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Tests/Fixtures/audio")
let dirContents = try? FileManager.default.contentsOfDirectory(at: fixturesDir, includingPropertiesForKeys: nil)
guard let entries = dirContents else { fail("픽스처 디렉터리를 읽을 수 없음") }
let fixtures = entries.filter { $0.pathExtension == "wav" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
guard !fixtures.isEmpty else { fail("픽스처 0개") }

let cachesURL = try? FileManager.default.url(
    for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
)
let modelFileName = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ggml-tiny.bin"
let modelURL = cachesURL?.appendingPathComponent("CallGuard/whisper-model-cache/\(modelFileName)")
guard let modelURL, FileManager.default.fileExists(atPath: modelURL.path) else {
    fail("모델 캐시 없음 — 먼저 실행: swift test --filter WhisperEngineTests")
}

let defaultSHA256 = "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21"
let modelSHA256 = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : defaultSHA256
let spec = WhisperModelSpec(expectedSHA256: modelSHA256)

for fixture in fixtures {
    guard let data = try? Data(contentsOf: fixture), let wav = try? WavFile.parse(data) else {
        fail("픽스처 파싱 실패: \(fixture.lastPathComponent)")
    }

    let wideText = transcribe(samples: wav.samples, sampleRate: wav.sampleRate, modelURL: modelURL, spec: spec)
    print("""
    {"fixture":"\(fixture.lastPathComponent)","band":"wide","transcript":\(jsonString(wideText))}
    """)

    let narrowBand = Resampler.resample(wav.samples, from: wav.sampleRate, to: 8000)
    let narrowText = transcribe(samples: narrowBand, sampleRate: 8000, modelURL: modelURL, spec: spec)
    print("""
    {"fixture":"\(fixture.lastPathComponent)","band":"narrow8k","transcript":\(jsonString(narrowText))}
    """)
}
