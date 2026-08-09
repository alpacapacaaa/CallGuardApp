import SwiftUI

/// CallGuard 앱 진입점.
/// 파이프라인 조합 루트이며, 온보딩·동의 게이트는 P4에서 구현한다.
@main
struct CallGuardApp: App {
    var body: some Scene {
        WindowGroup {
            Text("CallGuard")
        }
    }
}
