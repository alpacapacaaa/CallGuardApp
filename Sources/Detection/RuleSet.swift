/// RuleEngine typed error (AGENTS.md §5).
public enum RuleEngineError: Error, Sendable, Equatable {
    case signatureMismatch
    case notUtf8
    case invalidFormat(detail: String)
    case emptyRules
}

/// 룰 1건 — 카테고리 1개 + 키워드 매칭 조건.
public struct Rule: Sendable, Hashable {
    public let id: String
    public let category: RiskCategory
    public let weight: Double
    public let keywords: [String]
}

/// rules.yaml 스키마(P3-T2, F-S5) 파서.
/// 일반 YAML 파서가 아니라 이 고정 스키마 전용 최소 파서 — 외부 의존성 없이 직접 구현
/// (AGENTS.md §8-5, G10). 지원 형태:
/// ```
/// version: 1
/// rules:
///   - id: <string>
///     category: <RiskCategory rawValue>
///     weight: <Double>
///     keywords:
///       - <string>
/// ```
public enum RuleSet {
    /// 룰 1건을 라인 단위로 누적하는 빌더 — parse()의 분기 복잡도를 낮추기 위해 분리.
    private struct Builder {
        var id: String?
        var category: RiskCategory?
        var weight: Double?
        var keywords: [String] = []
        var inKeywords = false

        mutating func reset(id newID: String) {
            id = newID
            category = nil
            weight = nil
            keywords = []
            inKeywords = false
        }

        func build() throws -> Rule {
            guard let id else { throw RuleEngineError.invalidFormat(detail: "id 누락") }
            guard let category else { throw RuleEngineError.invalidFormat(detail: "\(id): category 누락") }
            guard let weight else { throw RuleEngineError.invalidFormat(detail: "\(id): weight 누락") }
            guard !keywords.isEmpty else { throw RuleEngineError.invalidFormat(detail: "\(id): keywords 누락") }
            return Rule(id: id, category: category, weight: weight, keywords: keywords)
        }
    }

    public static func parse(_ text: String) throws -> [Rule] {
        var rules: [Rule] = []
        var builder = Builder()

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            if trimmed.hasPrefix("- id:") {
                if builder.id != nil {
                    try rules.append(builder.build())
                }
                builder.reset(id: trimmed.dropFirst("- id:".count).trimmingCharacters(in: .whitespaces))
            } else {
                try apply(line: trimmed, to: &builder)
            }
        }
        if builder.id != nil {
            try rules.append(builder.build())
        }
        guard !rules.isEmpty else { throw RuleEngineError.emptyRules }
        return rules
    }

    /// `- id:`가 아닌 필드 라인(category/weight/keywords 항목) 1개를 빌더에 반영한다.
    private static func apply(line trimmed: String, to builder: inout Builder) throws {
        if trimmed.hasPrefix("category:") {
            let raw = trimmed.dropFirst("category:".count).trimmingCharacters(in: .whitespaces)
            guard let category = RiskCategory(rawValue: raw) else {
                throw RuleEngineError.invalidFormat(detail: "알 수 없는 category: \(raw)")
            }
            builder.category = category
            builder.inKeywords = false
        } else if trimmed.hasPrefix("weight:") {
            let raw = trimmed.dropFirst("weight:".count).trimmingCharacters(in: .whitespaces)
            guard let weight = Double(raw) else {
                throw RuleEngineError.invalidFormat(detail: "잘못된 weight: \(raw)")
            }
            builder.weight = weight
            builder.inKeywords = false
        } else if trimmed == "keywords:" {
            builder.inKeywords = true
        } else if trimmed.hasPrefix("- "), builder.inKeywords {
            builder.keywords.append(String(trimmed.dropFirst(2)))
        } else if trimmed.hasPrefix("version:") || trimmed == "rules:" {
            return
        } else {
            throw RuleEngineError.invalidFormat(detail: "인식 불가 라인: \(trimmed)")
        }
    }
}
