import Foundation
import STT

/// 1차 룰 + 2차 경량 분류기 결합, 60s 슬라이딩 윈도(P3-T5).
/// 룰이 하나도 매칭되지 않으면 nil — RiskScore.category(비옵셔널)에 근거 없는 값을 넣지 않는다.
public struct DetectionEngine: Sendable {
    public static let windowDuration: TimeInterval = 60

    private let ruleEngine: RuleEngine
    private let classifier: LinearClassifier
    private var window: [TranscriptSegment] = []

    public init(ruleEngine: RuleEngine, classifier: LinearClassifier) {
        self.ruleEngine = ruleEngine
        self.classifier = classifier
    }

    /// 새 세그먼트를 창에 추가(60s보다 오래된 세그먼트는 제거)하고 판정을 갱신한다.
    public mutating func evaluate(adding segment: TranscriptSegment) -> RiskScore? {
        window.append(segment)
        let cutoff = segment.endTime - Self.windowDuration
        window.removeAll { $0.endTime < cutoff }

        let windowText = window.map(\.text).joined(separator: " ")
        let matches = ruleEngine.evaluate(text: windowText)
        guard let topMatch = matches.max(by: { $0.weight < $1.weight }) else { return nil }

        let classifierScore = classifier.score(text: windowText)
        let value = min(max(classifierScore, topMatch.weight), 1.0)
        let matchedKeywords = Set(matches.flatMap(\.matchedKeywords))
        let evidence = window.filter { segment in
            let normalizedSegmentText = normalizedForMatching(segment.text)
            return matchedKeywords.contains { normalizedSegmentText.contains(normalizedForMatching($0)) }
        }

        return RiskScore(value: value, category: topMatch.category, evidence: evidence)
    }
}
