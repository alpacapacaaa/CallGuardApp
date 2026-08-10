import Capture
import Foundation

/// 트랙별 STT가 방출하는 전사 세그먼트 (P2-T3).
/// G1: 전사 원문은 로그·콘솔·임시파일에 노출 금지 — 디버깅은 길이·해시·타임스탬프만.
public struct TranscriptSegment: Sendable, Hashable {
    public let track: AudioTrack
    public let text: String
    /// 세션 시작 기준 발화 구간(초).
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    /// false = 스트리밍 중간 결과, true = 확정 발화.
    public let isFinal: Bool

    public init(
        track: AudioTrack,
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        isFinal: Bool
    ) {
        self.track = track
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.isFinal = isFinal
    }
}
