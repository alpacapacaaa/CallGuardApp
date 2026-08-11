import AlertPolicy
import AppKit
import SwiftUI

/// CallGuard 앱 진입점. 저장소 루트에서 실행해야 한다(rules.yaml·모델 캐시를 상대 경로로 찾음):
/// swift run --disable-keychain CallGuardApp
///
/// 제어판은 SwiftUI WindowGroup이 아니라 AppKit NSWindow(ControlPanelWindowController)로
/// 띄운다. 이유는 두 가지: (1) MenuBarExtra 팝업(.window 스타일)은 임시(transient) 창이라 그
/// 안에서 파일 선택창(AppKit NSOpenPanel도, SwiftUI .fileImporter도)을 열면 팝업이 포커스를
/// 잃으며 통째로 닫혀버리는 문제가 실측으로 확인됐다. (2) WindowGroup + .windowResizability
/// (.contentSize) + .defaultSize 조합은 메뉴바 전용 앱에서 창 프레임과 SwiftUI 콘텐츠의 실제
/// 렌더 크기가 어긋나 콘텐츠 좌우가 창 경계에 잘려 보이는 문제, 그리고 openWindow(id:) 호출마다
/// 새 창이 열려 같은 내용의 창이 중복으로 뜨는 문제가 실측으로 확인됐다(Secure Restorable
/// State 비활성화·activate 순서 조정만으로는 해결되지 않음, swift run으로 재현). 이미 검증된
/// DangerWindowController와 동일한 AppKit 직접 제어 방식으로 두 문제를 모두 제거한다.
/// macOS의 창 크기/위치 자동 저장·복원(Secure Restorable State)도 계속 꺼 둔다 — AppKit
/// NSWindow도 기본적으로 이 복원 대상이라, 켜져 있으면 이전 실행의 잘못된 프레임이 복원될 수
/// 있다.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        false
    }
}

@main
struct CallGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    @State private var controlPanelWindow: ControlPanelWindowController?

    var body: some Scene {
        MenuBarExtra {
            Button("제어판 열기") {
                if controlPanelWindow == nil {
                    controlPanelWindow = ControlPanelWindowController(appState: appState)
                }
                controlPanelWindow?.present()
            }
            Divider()
            Button("종료") { NSApp.terminate(nil) }
        } label: {
            // MenuBarStateView(P4-T2)는 docs/ui/ 스크린샷용 44×44 프레임이라 실제 메뉴바
            // 라벨에는 안 맞음 — 메뉴바 크기에 맞는 최소 아이콘을 직접 구성.
            Image(systemName: "shield.fill")
                .foregroundStyle(menuBarColor)
        }
    }

    private var menuBarColor: Color {
        switch appState.alertLevel {
        case .none: .secondary
        case .caution: .orange
        case .danger: .red
        }
    }
}
