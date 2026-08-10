import Foundation

/// 룰 1건이 텍스트에 매칭된 결과.
public struct RuleMatch: Sendable, Hashable {
    public let ruleID: String
    public let category: RiskCategory
    public let weight: Double
    public let matchedKeywords: [String]
}

/// 1차 탐지 룰 엔진(P3-T2, F-M4). rules.yaml 로드 시 서명 검증(F-S5) 필수 —
/// 서명 불일치는 조용히 넘어가지 않고 typed error로 로드 자체를 거부한다.
public struct RuleEngine: Sendable {
    public let rules: [Rule]

    public init(rules: [Rule]) {
        self.rules = rules
    }

    /// rulesData의 SHA256 다이제스트가 expectedSignature(hex, 대소문자 무관)와 일치할 때만 로드한다.
    public static func load(rulesData: Data, expectedSignature: String) throws -> RuleEngine {
        let actual = RuleSignature.hexDigest(of: rulesData)
        guard actual.caseInsensitiveCompare(expectedSignature) == .orderedSame else {
            throw RuleEngineError.signatureMismatch
        }
        guard let text = String(data: rulesData, encoding: .utf8) else {
            throw RuleEngineError.notUtf8
        }
        return try RuleEngine(rules: RuleSet.parse(text))
    }

    /// 텍스트에 매칭되는 룰 전부를 반환한다(순서 = rules.yaml 정의 순서).
    public func evaluate(text: String) -> [RuleMatch] {
        rules.compactMap { rule in
            let matched = rule.keywords.filter { text.contains($0) }
            guard !matched.isEmpty else { return nil }
            return RuleMatch(ruleID: rule.id, category: rule.category, weight: rule.weight, matchedKeywords: matched)
        }
    }
}
