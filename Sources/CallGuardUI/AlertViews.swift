import AlertPolicy
import SwiftUI

/// 메뉴바 3상태 아이콘(F-M5).
public struct MenuBarStateView: View {
    let viewModel: AlertViewModel

    public init(viewModel: AlertViewModel) {
        self.viewModel = viewModel
    }

    private var color: Color {
        switch viewModel.level {
        case .none: .secondary
        case .caution: .orange
        case .danger: .red
        }
    }

    public var body: some View {
        Image(systemName: "shield.fill")
            .foregroundStyle(color)
            .font(.system(size: 18))
            .frame(width: 44, height: 44)
    }
}

/// 주의 배너(값 ≥0.5) — 최소 정보만.
public struct CautionBannerView: View {
    let viewModel: AlertViewModel

    public init(viewModel: AlertViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text("주의 — \(viewModel.categoryLabel ?? "의심 정황") 가능성이 있습니다")
                .font(.callout)
        }
        .padding()
        .background(Color.orange.opacity(0.15))
        // 고정 폭(360)을 강제하지 않고 부모가 준 폭에 맞춘다 — ControlPanelView(폭 340)처럼
        // 더 좁은 컨테이너 안에 들어가면 고정 폭이 컨테이너보다 커져 전체 레이아웃이 중앙
        // 정렬되며 왼쪽으로 밀려 보이는 문제가 있었다. 독립 렌더링(RenderUIStates)에서
        // 필요한 고정 폭은 호출부에서 지정한다.
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 위험 전면 패널(값 ≥0.8) — 유형+근거 2–3건+권장행동+[무시].
public struct DangerPanelView: View {
    let viewModel: AlertViewModel
    public var onDismiss: () -> Void = {}

    public init(viewModel: AlertViewModel, onDismiss: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("보이스피싱 위험", systemImage: "exclamationmark.octagon.fill")
                .font(.title2.bold())
                .foregroundStyle(.red)
            if let category = viewModel.categoryLabel {
                Text("유형: \(category)").font(.headline)
            }
            if !viewModel.evidenceLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("근거 발화").font(.subheadline.bold())
                    ForEach(viewModel.evidenceLines, id: \.self) { line in
                        Text("• \(line)").font(.caption)
                    }
                }
            }
            if let action = viewModel.recommendedAction {
                Text(action).font(.callout)
            }
            Button("무시", action: onDismiss)
        }
        .padding(20)
        .frame(width: 420)
        .background(Color.red.opacity(0.08))
    }
}
