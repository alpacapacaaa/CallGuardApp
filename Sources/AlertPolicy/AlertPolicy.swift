import Detection

public enum AlertLevel: Sendable, Equatable {
    case none
    case caution
    case danger
}

/// 경고 상태 머신(P3-T6). 임계값 0.5(주의)/0.8(위험) + 히스테리시스(하강 임계를 낮게 잡아
/// 경계값 근처 진동으로 인한 깜빡임 방지) + [무시] 후 세션 내 동일 카테고리 재경고 억제.
public struct AlertPolicy: Sendable {
    public private(set) var level: AlertLevel = .none
    private var dismissedCategories: Set<RiskCategory> = []

    public init() {}

    /// 새 판정을 반영해 레벨을 갱신한다. score가 nil이거나 카테고리가 무시됨이면 하강 압력만 준다.
    @discardableResult
    public mutating func update(with score: RiskScore?) -> AlertLevel {
        guard let score, !dismissedCategories.contains(score.category) else {
            return step(value: 0)
        }
        return step(value: score.value)
    }

    /// 세션 내 해당 카테고리 재경고를 억제한다 — 즉시 none으로 하강.
    public mutating func dismiss(category: RiskCategory) {
        dismissedCategories.insert(category)
        level = .none
    }

    private mutating func step(value: Double) -> AlertLevel {
        switch level {
        case .none:
            if value >= 0.8 {
                level = .danger
            } else if value >= 0.5 {
                level = .caution
            }
        case .caution:
            if value >= 0.8 {
                level = .danger
            } else if value < 0.4 {
                level = .none
            }
        case .danger:
            if value < 0.4 {
                level = .none
            } else if value < 0.7 {
                level = .caution
            }
        }
        return level
    }
}
