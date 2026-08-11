import AlertPolicy
import AppKit
import SwiftUI

/// CallGuard 앱 진입점. 저장소 루트에서 실행해야 한다(rules.yaml·모델 캐시를 상대 경로로 찾음):
/// swift run --disable-keychain CallGuardApp
///
/// 제어판은 MenuBarExtra 팝업이 아니라 일반 WindowGroup 창으로 띄운다 — 팝업(.window 스타일)은
/// 임시(transient) 창이라 그 안에서 파일 선택창(AppKit NSOpenPanel도, SwiftUI .fileImporter도)을
/// 열면 팝업이 포커스를 잃으며 통째로 닫혀버리는 문제가 실측으로 확인됐다. 일반 창은 이 문제가 없다.
@main
struct CallGuardApp: App {
    @State private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            Button("제어판 열기") { openWindow(id: "control-panel") }
            Divider()
            Button("종료") { NSApp.terminate(nil) }
        } label: {
            // MenuBarStateView(P4-T2)는 docs/ui/ 스크린샷용 44×44 프레임이라 실제 메뉴바
            // 라벨에는 안 맞음 — 메뉴바 크기에 맞는 최소 아이콘을 직접 구성.
            Image(systemName: "shield.fill")
                .foregroundStyle(menuBarColor)
        }

        WindowGroup(id: "control-panel") {
            ControlPanelView(appState: appState)
        }
        .windowResizability(.contentSize)
    }

    private var menuBarColor: Color {
        switch appState.alertLevel {
        case .none: .secondary
        case .caution: .orange
        case .danger: .red
        }
    }
}
