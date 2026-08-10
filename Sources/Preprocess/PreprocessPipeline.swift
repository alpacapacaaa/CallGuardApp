import Capture
import Foundation

/// 캡처 청크(임의 샘플레이트·임의 길이)를 16kHz·2s 단위 `PreprocessedChunk`로 재조립한다(P2-T1).
/// ChunkAccumulator(Capture)와 동일한 누적-방출 계약: feed()가 완성된 청크들을 반환하고,
/// 잔여분은 flush()로 명시적으로 비운다.
public struct PreprocessPipeline: Sendable {
    public static let targetSampleRate = 16000
    public static let chunkDuration: TimeInterval = 2.0

    public let track: AudioTrack
    private let chunkFrames: Int
    private var pending: [Float] = []
    /// 지금까지 방출한(flush 포함) 16kHz 프레임 누계 — startTime 계산 기준.
    private var emittedFrames = 0

    public init(track: AudioTrack) {
        self.track = track
        chunkFrames = max(1, Int((Double(Self.targetSampleRate) * Self.chunkDuration).rounded()))
    }

    /// 캡처 청크 하나를 리샘플링·누적하고, 완성된 2s 청크들을 방출 순서대로 반환한다.
    public mutating func feed(_ chunk: AudioChunk) -> [PreprocessedChunk] {
        let resampled = Resampler.resample(chunk.samples, from: chunk.sampleRate, to: Self.targetSampleRate)
        pending.append(contentsOf: resampled)
        var results: [PreprocessedChunk] = []
        while pending.count >= chunkFrames {
            let segment = Array(pending[..<chunkFrames])
            results.append(makeChunk(segment))
            emittedFrames += chunkFrames
            pending.removeFirst(chunkFrames)
        }
        return results
    }

    /// 스트림 종료 시 잔여 샘플을 마지막(짧은) 청크로 방출한다 — 잔여분이 없으면 nil.
    public mutating func flush() -> PreprocessedChunk? {
        guard !pending.isEmpty else { return nil }
        let segment = pending
        let chunk = makeChunk(segment)
        emittedFrames += segment.count
        pending.removeAll()
        return chunk
    }

    private func makeChunk(_ segment: [Float]) -> PreprocessedChunk {
        PreprocessedChunk(
            track: track,
            samples: segment,
            sampleRate: Self.targetSampleRate,
            startTime: Double(emittedFrames) / Double(Self.targetSampleRate),
            isSpeech: VoiceActivityDetector.isSpeech(segment)
        )
    }
}
