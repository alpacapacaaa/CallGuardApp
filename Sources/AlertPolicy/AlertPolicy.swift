import Detection

public enum AlertLevel: Sendable, Equatable {
    case none
    case caution
    case danger
}

/// 민감도 3단계 프리셋(F-S3) — 임계값 세트를 통째로 교체한다. medium이 P3-T6 원안(0.5/0.8) 그대로.
public enum SensitivityPreset: String, Sendable, CaseIterable {
    case low
    case medium
    case high

    fileprivate var thresholds: AlertThresholds {
        switch self {
        case .low: AlertThresholds(cautionUp: 0.65, dangerUp: 0.90, cautionDown: 0.80, noneDown: 0.55)
        case .medium: AlertThresholds(cautionUp: 0.50, dangerUp: 0.80, cautionDown: 0.70, noneDown: 0.40)
        case .high: AlertThresholds(cautionUp: 0.35, dangerUp: 0.65, cautionDown: 0.55, noneDown: 0.25)
        }
    }
}

private struct AlertThresholds: Sendable {
    let cautionUp: Double
    let dangerUp: Double
    let cautionDown: Double
    let noneDown: Double
}

/// 경고 상태 머신(P3-T6). 임계값 + 히스테리시스(하강 임계를 낮게 잡아 경계값 근처 진동으로 인한
/// 깜빡임 방지) + [무시] 후 세션 내 동일 카테고리 재경고 억제(F-S2).
public struct AlertPolicy: Sendable {
    public private(set) var level: AlertLevel = .none
    /// [무시] 처리된 카테고리 이력 — 로컬 오탐 목록(F-S2).
    public private(set) var dismissalLog: [RiskCategory] = []
    private var dismissedCategories: Set<RiskCategory> = []
    private let thresholds: AlertThresholds

    public init(sensitivity: SensitivityPreset = .medium) {
        thresholds = sensitivity.thresholds
    }

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
        dismissalLog.append(category)
        level = .none
    }

    private mutating func step(value: Double) -> AlertLevel {
        switch level {
        case .none:
            if value >= thresholds.dangerUp {
                level = .danger
            } else if value >= thresholds.cautionUp {
                level = .caution
            }
        case .caution:
            if value >= thresholds.dangerUp {
                level = .danger
            } else if value < thresholds.noneDown {
                level = .none
            }
        case .danger:
            if value < thresholds.noneDown {
                level = .none
            } else if value < thresholds.cautionDown {
                level = .caution
            }
        }
        return level
    }
}
