import Capture
import Foundation

/// 전처리 완료 청크. 16kHz로 리샘플링되고 2s 단위로 재조립된 뒤 VAD 태그가 붙는다(P2-T1).
/// 파이프라인 타입 — Sendable 불변 struct (AGENTS.md §5).
public struct PreprocessedChunk: Sendable, Hashable {
    public let track: AudioTrack
    public let samples: [Float]
    public let sampleRate: Int
    /// 세션(스트림) 시작 기준 이 청크의 시작 시각(초).
    public let startTime: TimeInterval
    /// 프레임 에너지 기반 VAD 판정 — true면 발화 구간.
    public let isSpeech: Bool

    public init(
        track: AudioTrack,
        samples: [Float],
        sampleRate: Int,
        startTime: TimeInterval,
        isSpeech: Bool
    ) {
        self.track = track
        self.samples = samples
        self.sampleRate = sampleRate
        self.startTime = startTime
        self.isSpeech = isSpeech
    }

    public var duration: TimeInterval {
        Double(samples.count) / Double(sampleRate)
    }
}
