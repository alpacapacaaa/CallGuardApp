import AppKit
import SwiftUI

/// 제어판 창을 SwiftUI WindowGroup이 아니라 AppKit NSWindow로 직접 관리한다.
/// WindowGroup + .windowResizability(.contentSize) + .defaultSize 조합은 메뉴바 전용 앱에서
/// 실측으로 두 가지 문제가 반복 확인됐다: (1) 초기 창 프레임이 SwiftUI 콘텐츠의 실제 렌더
/// 크기와 어긋나 콘텐츠 좌우가 창 경계에 잘려 보임(Secure Restorable State 비활성화·activate
/// 순서 조정으로도 해결 안 됨), (2) openWindow(id:)를 호출할 때마다 새 창이 열려 같은 내용의
/// 창이 여러 개 겹쳐 뜸. DangerWindowController와 동일하게 NSWindow + NSHostingController로
/// 직접 제어하고 controller를 재사용해 두 문제를 모두 제거한다.
///
/// 창 크기를 고정하고 강제 리레이아웃을 거는 시도(창이 key가 아닐 때 콘텐츠가 왼쪽으로 밀려
/// 보이는 문제 대응)도 해봤지만 오히려 더 불안정했다(실사용 피드백) — sizingOptions 기본값
/// (.standardBounds, 콘텐츠의 이상적 크기에 맞춰 창을 자동 리사이즈)으로 되돌리는 게 실사용
/// 기준 가장 안정적이었다. ControlPanelView의 폭이 고정(.frame(width: 340))이라 실제로
/// 자동 리사이즈되는 건 높이뿐 — 자막이 쌓이면 창이 아래로 늘어나고, 폭은 그대로 유지된다.
@MainActor
final class ControlPanelWindowController: NSWindowController {
    convenience init(appState: AppState) {
        let hostingController = NSHostingController(rootView: ControlPanelView(appState: appState))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 650),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CallGuard 제어판"
        window.contentViewController = hostingController
        // DangerWindowController(.floating)와 달리 이 창은 기본 레벨(.normal)이라 통화 중
        // 다른 앱(전화 앱, 카카오톡 알림 등)에 쉽게 가려진다 — 위험 판정 팝업이 뜨기 전까지는
        // 자막이 안 보인다는 문제가 실측으로 확인됐다(위험 팝업만 유일하게 강제로 앞에 옴).
        // 제어판을 켜 두는 동안은 계속 다른 창 위에 떠 있게 해 실시간 자막이 항상 보이게 한다.
        window.level = .floating
        // 닫기 버튼으로 닫아도 창 인스턴스를 유지해 다음 "제어판 열기" 클릭에서 재사용한다
        // (기본값 true면 close 시 창이 해제되어 재사용 시 빈 창이 뜬다).
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
