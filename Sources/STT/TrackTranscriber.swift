import Capture
import Foundation
import Preprocess

/// 트랙별 독립 스트리밍 STT(P2-T3). remote/local은 각자 WhisperEngine·PreprocessPipeline을
/// 갖는다 — 상태 공유 없음(비혼합 보장).
public struct TrackTranscriber {
    private let track: AudioTrack
    private let engine: WhisperEngine
    private var pipeline: PreprocessPipeline

    public init(track: AudioTrack, engine: WhisperEngine) {
        self.track = track
        self.engine = engine
        pipeline = PreprocessPipeline(track: track)
    }

    public mutating func feed(_ chunk: AudioChunk) throws -> [TranscriptSegment] {
        try pipeline.feed(chunk).map(segment)
    }

    public mutating func flush() throws -> TranscriptSegment? {
        try pipeline.flush().map(segment)
    }

    private func segment(from chunk: PreprocessedChunk) throws -> TranscriptSegment {
        let text = try engine.transcribe(samples: chunk.samples)
        return TranscriptSegment(
            track: track,
            text: text,
            startTime: chunk.startTime,
            endTime: chunk.startTime + chunk.duration,
            isFinal: true
        )
    }
}
