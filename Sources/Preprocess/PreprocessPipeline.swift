import Capture
import Foundation

/// 캡처 청크(임의 샘플레이트·임의 길이)를 16kHz `PreprocessedChunk`로 재조립한다(P2-T1).
/// ChunkAccumulator(Capture)와 동일한 누적-방출 계약: feed()가 완성된 청크들을 반환하고,
/// 잔여분은 flush()로 명시적으로 비운다.
///
/// 청크 경계는 고정 길이가 아니라 발화 사이 무음(VAD)에서 우선 끊는다(2026-08-11) — 고정 8s
/// 컷은 문장 중간을 잘라 자막이 부자연스럽고 지연도 최대치로 고정됐다. minChunkDuration 이상
/// 쌓이고 최근 silenceProbeDuration 구간이 무음이면 그 지점에서 조기 컷, 무음이 없으면
/// chunkDuration에서 강제 컷(상한 — CER 실측 근거는 docs/stt-benchmark.md).
public struct PreprocessPipeline: Sendable {
    public static let targetSampleRate = 16000
    public static let chunkDuration: TimeInterval = 8.0
    public static let minChunkDuration: TimeInterval = 3.0
    public static let silenceProbeDuration: TimeInterval = 0.5

    public let track: AudioTrack
    private let chunkFrames: Int
    private let minChunkFrames: Int
    private let silenceProbeFrames: Int
    private var pending: [Float] = []
    /// 지금까지 방출한(flush 포함) 16kHz 프레임 누계 — startTime 계산 기준.
    private var emittedFrames = 0

    public init(track: AudioTrack) {
        self.track = track
        chunkFrames = max(1, Int((Double(Self.targetSampleRate) * Self.chunkDuration).rounded()))
        minChunkFrames = max(1, Int((Double(Self.targetSampleRate) * Self.minChunkDuration).rounded()))
        silenceProbeFrames = max(1, Int((Double(Self.targetSampleRate) * Self.silenceProbeDuration).rounded()))
    }

    /// 캡처 청크 하나를 리샘플링·누적하고, 완성된 청크들을 방출 순서대로 반환한다.
    public mutating func feed(_ chunk: AudioChunk) -> [PreprocessedChunk] {
        let resampled = Resampler.resample(chunk.samples, from: chunk.sampleRate, to: Self.targetSampleRate)
        pending.append(contentsOf: resampled)
        var results: [PreprocessedChunk] = []
        while let cutFrame = cutPoint() {
            let segment = Array(pending[..<cutFrame])
            results.append(makeChunk(segment))
            emittedFrames += cutFrame
            pending.removeFirst(cutFrame)
        }
        return results
    }

    /// 방출할 프레임 수를 정한다 — 상한(chunkDuration) 우선 확인, 아니면 최근 구간이 무음이고
    /// 최소 길이(minChunkDuration)를 채웠을 때만 조기 컷. 둘 다 아니면 더 모은다(nil).
    private func cutPoint() -> Int? {
        if pending.count >= chunkFrames {
            return chunkFrames
        }
        guard pending.count >= minChunkFrames + silenceProbeFrames else { return nil }
        let tail = pending.suffix(silenceProbeFrames)
        guard !VoiceActivityDetector.isSpeech(Array(tail)) else { return nil }
        return pending.count
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
