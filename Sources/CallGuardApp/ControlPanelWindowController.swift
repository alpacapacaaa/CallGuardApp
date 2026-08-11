import AppKit
import SwiftUI

/// 제어판 창을 SwiftUI WindowGroup이 아니라 AppKit NSWindow로 직접 관리한다.
/// WindowGroup + .windowResizability(.contentSize) + .defaultSize 조합은 메뉴바 전용 앱에서
/// 실측으로 두 가지 문제가 반복 확인됐다: (1) 초기 창 프레임이 SwiftUI 콘텐츠의 실제 렌더
/// 크기와 어긋나 콘텐츠 좌우가 창 경계에 잘려 보임(Secure Restorable State 비활성화·activate
/// 순서 조정으로도 해결 안 됨), (2) openWindow(id:)를 호출할 때마다 새 창이 열려 같은 내용의
/// 창이 여러 개 겹쳐 뜸. DangerWindowController와 동일하게 고정 프레임 NSWindow +
/// NSHostingView로 직접 제어하고 controller를 재사용해 두 문제를 모두 제거한다.
@MainActor
final class ControlPanelWindowController: NSWindowController {
    convenience init(appState: AppState) {
        let hostingView = NSHostingView(rootView: ControlPanelView(appState: appState))
        // NSHostingView의 sizingOptions 기본값(.standardBounds)은 SwiftUI 콘텐츠의 이상적
        // 크기에 맞춰 "창 자체"를 계속 자동 리사이즈한다. 제어판은 실시간 캡처 중 자막이
        // 계속 추가되며 콘텐츠 높이가 매 세그먼트마다 바뀌는데, 그때마다 창 프레임을 자동
        // 재계산하면서 창이 왼쪽으로 밀리거나 레이아웃이 깨져 보이는 문제가 실측으로 확인됐다
        // (정적 화면에서는 재현 안 되고 실제 실시간 캡처 중에만 재현). 자동 리사이즈를 끄고
        // 창 크기를 고정해, 콘텐츠는 내부 ScrollView(자막)로만 넘치게 한다.
        hostingView.sizingOptions = []
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CallGuard 제어판"
        window.contentView = hostingView
        window.contentMinSize = NSSize(width: 380, height: 600)
        window.contentMaxSize = NSSize(width: 380, height: 600)
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
