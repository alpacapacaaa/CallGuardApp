@testable import Capture
import Foundation
@testable import STT
import Testing

/// DoD(P2-T2) 단발 추론 테스트. 네트워크 필요(slow 레인) — 최초 실행 시 ggml-tiny(~75MB)와
/// 샘플 WAV를 1회 다운로드해 macOS 사용자 캐시 디렉터리에 저장, 이후 실행은 재사용한다.
/// 모델·샘플은 저장소에 커밋하지 않는다(G5, 용량·라이선스).
struct WhisperEngineTests {
    /// 2026-08-11 다운로드 시점에 이 에이전트가 직접 계산한 해시(TOFU) — 공식 체크섬 배포처가
    /// 없어(models/download-ggml-model.sh 확인) 최초 다운로드 시점 값을 고정한다.
    private static let tinyModelSHA256 = "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21"
    private static let modelHost = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"
    private static let sampleHost = "https://github.com/ggml-org/whisper.cpp/raw/master/samples"
    private static let modelDownloadURL = URL(string: "\(modelHost)/ggml-tiny.bin")!
    private static let sampleDownloadURL = URL(string: "\(sampleHost)/jfk.wav")!

    private static func cacheDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let dir = base.appendingPathComponent("CallGuard/whisper-model-cache", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func cachedFile(named name: String, downloadingFrom url: URL) async throws -> URL {
        let destination = try cacheDirectory().appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw STTError.modelLoadFailed(path: url.absoluteString)
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    @Test func transcribesSampleAudio() async throws {
        let modelURL = try await Self.cachedFile(named: "ggml-tiny.bin", downloadingFrom: Self.modelDownloadURL)
        let sampleURL = try await Self.cachedFile(named: "jfk.wav", downloadingFrom: Self.sampleDownloadURL)

        let engine = try WhisperEngine(
            modelURL: modelURL,
            spec: WhisperModelSpec(expectedSHA256: Self.tinyModelSHA256)
        )

        let wavData = try Data(contentsOf: sampleURL)
        let file = try WavFile.parse(wavData)
        // jfk.wav는 whisper.cpp 공식 영어 샘플 — 언어를 en으로 지정(한국어 강제 시 오탐 가능성).
        let text = try engine.transcribe(samples: file.samples, language: "en")

        #expect(!text.isEmpty)
    }

    @Test func rejectsTamperedModelBeforeLoading() async throws {
        let modelURL = try await Self.cachedFile(named: "ggml-tiny.bin", downloadingFrom: Self.modelDownloadURL)
        let wrongSpec = WhisperModelSpec(expectedSHA256: String(repeating: "f", count: 64))
        do {
            _ = try WhisperEngine(modelURL: modelURL, spec: wrongSpec)
            Issue.record("해시가 다른데 로드가 성공함")
        } catch let error as STTError {
            guard case .modelHashMismatch = error else {
                Issue.record("예상치 못한 STTError: \(error)")
                return
            }
        }
    }
}
