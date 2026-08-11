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

    /// 무음 청크는 whisper에 넣지 않는다 — 침묵을 넣으면 관련 없는 텍스트를 지어내는
    /// 할루시네이션이 발생함(실측: 실음성 10건 CER 93.1%, 원인은 청크 끝마다 "감사합니다" 등
    /// 무관 텍스트 삽입). VAD(PreprocessPipeline)가 이미 계산해 둔 isSpeech를 게이트로 사용.
    public mutating func feed(_ chunk: AudioChunk) throws -> [TranscriptSegment] {
        try pipeline.feed(chunk).filter(\.isSpeech).map(segment)
    }

    public mutating func flush() throws -> TranscriptSegment? {
        guard let chunk = pipeline.flush(), chunk.isSpeech else { return nil }
        return try segment(from: chunk)
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
