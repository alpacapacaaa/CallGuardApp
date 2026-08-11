import AppKit
import CallGuardUI
import SwiftUI

/// 위험 전면 패널(F-M5)을 별도 플로팅 창으로 띄운다. SwiftUI의 선언적 다중 윈도(WindowGroup)는
/// 메뉴바 전용 앱에서 자동 표시 타이밍이 불안정해, 판정 즉시 확실히 뜨도록 AppKit으로 직접 제어.
@MainActor
final class DangerWindowController: NSWindowController {
    convenience init(viewModel: AlertViewModel, onDismiss: @escaping () -> Void) {
        let hostingView = NSHostingView(rootView: DangerPanelView(viewModel: viewModel, onDismiss: onDismiss))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "보이스피싱 위험 경고"
        window.level = .floating
        window.contentView = hostingView
        window.center()
        self.init(window: window)
    }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
