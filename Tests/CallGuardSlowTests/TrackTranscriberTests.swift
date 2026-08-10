@testable import Capture
import Foundation
@testable import STT
import Testing

/// DoD(P2-T3): 픽스처 리플레이 → 두 트랙 전사 비혼합·순서 보장. 짧은 오디오(~3s)로
/// 추론 횟수를 최소화 — 캐시된 tiny 모델 재사용(P2-T2 슬로우 테스트와 동일 경로).
struct TrackTranscriberTests {
    private static let tinyModelSHA256 = "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21"
    private static let modelHost = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"
    private static let modelDownloadURL = URL(string: "\(modelHost)/ggml-tiny.bin")!

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

    @Test func perTrackSegmentsStayTaggedAndOrdered() async throws {
        let modelURL = try await Self.cachedModel()
        let spec = WhisperModelSpec(expectedSHA256: Self.tinyModelSHA256)

        var remote = try TrackTranscriber(track: .remote, engine: WhisperEngine(modelURL: modelURL, spec: spec))
        var local = try TrackTranscriber(track: .local, engine: WhisperEngine(modelURL: modelURL, spec: spec))

        // 3초 톤 — feed()에서 2s 청크 1개, flush()에서 1s 잔여 청크 1개 → 트랙당 세그먼트 2개.
        let samples = (0 ..< 48000).map { Float(sin(2 * Double.pi * 440 * Double($0) / 16000)) * 0.3 }
        let chunk = { (track: AudioTrack) in
            AudioChunk(track: track, samples: samples, sampleRate: 16000, capturedAt: Date())
        }

        var remoteSegments = try remote.feed(chunk(.remote))
        if let last = try remote.flush() {
            remoteSegments.append(last)
        }
        var localSegments = try local.feed(chunk(.local))
        if let last = try local.flush() {
            localSegments.append(last)
        }

        #expect(remoteSegments.count == 2)
        #expect(localSegments.count == 2)
        #expect(remoteSegments.allSatisfy { $0.track == .remote })
        #expect(localSegments.allSatisfy { $0.track == .local })
        #expect(remoteSegments.map(\.startTime) == remoteSegments.map(\.startTime).sorted())
        #expect(localSegments.map(\.startTime) == localSegments.map(\.startTime).sorted())
    }
}
