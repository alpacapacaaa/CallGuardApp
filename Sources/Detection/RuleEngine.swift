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
    /// 공백 제거 후 비교 — STT 결과의 띄어쓰기가 일정치 않아(예: "안전계좌"↔"안전 계좌") 원문
    /// 그대로 비교하면 의미가 같아도 놓친다(실측: G-3 조사에서 미탐 3건 중 2건이 이 원인).
    public func evaluate(text: String) -> [RuleMatch] {
        let normalizedText = normalizedForMatching(text)
        return rules.compactMap { rule in
            let matched = rule.keywords.filter { normalizedText.contains(normalizedForMatching($0)) }
            guard !matched.isEmpty else { return nil }
            return RuleMatch(ruleID: rule.id, category: rule.category, weight: rule.weight, matchedKeywords: matched)
        }
    }
}

/// 공백 제거 정규화 — RuleEngine.evaluate와 DetectionEngine의 근거 세그먼트 검색이 동일 기준을 쓴다.
func normalizedForMatching(_ text: String) -> String {
    text.filter { !$0.isWhitespace }
}
