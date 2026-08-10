import Detection
import Foundation
import STT

/// 위험도 타임라인 한 칸(F-S1) — 세그먼트 하나가 갱신한 판정+경고 레벨.
public struct TimelineEntry: Sendable, Equatable {
    public let time: TimeInterval
    public let level: AlertLevel
    public let value: Double
    public let category: RiskCategory?
}

/// 통화 종료 후 세션 리포트(F-S1: 위험도 타임라인+근거, F-S2: 로컬 오탐 목록).
public struct SessionReport: Sendable {
    public let timeline: [TimelineEntry]
    /// 경고에 기여한 근거 발화 — 중복 없이 최초 등장 순서 유지.
    public let evidence: [TranscriptSegment]
    public let falsePositiveCategories: [RiskCategory]
}

/// SessionReport를 세그먼트 단위 스트리밍으로 축적한다 — DetectionEngine/AlertPolicy와 나란히
/// 매 세그먼트마다 record()를 호출하고, 통화 종료 시 build()로 리포트를 확정한다.
public struct SessionReportBuilder: Sendable {
    private var timeline: [TimelineEntry] = []
    private var evidence: [TranscriptSegment] = []
    private var seenEvidence: Set<TranscriptSegment> = []

    public init() {}

    public mutating func record(segment: TranscriptSegment, score: RiskScore?, level: AlertLevel) {
        timeline.append(TimelineEntry(
            time: segment.endTime, level: level, value: score?.value ?? 0, category: score?.category
        ))
        guard let score else { return }
        for item in score.evidence where !seenEvidence.contains(item) {
            seenEvidence.insert(item)
            evidence.append(item)
        }
    }

    public func build(falsePositiveCategories: [RiskCategory]) -> SessionReport {
        SessionReport(timeline: timeline, evidence: evidence, falsePositiveCategories: falsePositiveCategories)
    }
}
