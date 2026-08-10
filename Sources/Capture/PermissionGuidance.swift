import Foundation

/// 권한 거부 시 사용자가 취할 조치를 담은 안내 상태 (P1-T5).
/// 크래시나 예외 전파 대신 이 상태로 종료한다는 계약 — TCC 상태를 조작할 수 없는
/// 환경에서도 매핑 자체는 순수·결정적이므로 fast 레인에서 검증 가능하다.
public struct PermissionGuidance: Sendable, Equatable {
    /// 프로세스 종료 코드. 권한 종류별로 구분해 운영자·스크립트가 원인 특정 가능.
    public let exitCode: Int32
    /// 한 줄 요약(표준오류 첫 행).
    public let title: String
    /// 사용자가 따라 할 복구 절차.
    public let instruction: String

    /// 오류가 권한 거부면 안내 상태를, 아니면 nil을 반환한다(일반 실패 경로와 구분).
    /// 전 입력에 대해 총함수 — 어떤 CaptureError에도 크래시 없이 판정한다.
    public static func from(_ error: CaptureError) -> PermissionGuidance? {
        switch error {
        case .screenCaptureDenied:
            PermissionGuidance(
                exitCode: 3,
                title: "화면녹화 권한이 없습니다.",
                instruction: """
                시스템 설정 → 개인 정보 보호 및 보안 → 화면 녹화에서 이 데모를 실행한 \
                상위 앱(예: 터미널)을 허용한 뒤 다시 실행하세요.
                """
            )
        case .microphoneDenied:
            PermissionGuidance(
                exitCode: 4,
                title: "마이크 권한이 없습니다.",
                instruction: """
                시스템 설정 → 개인 정보 보호 및 보안 → 마이크에서 이 데모를 실행한 \
                상위 앱(예: 터미널)을 허용한 뒤 다시 실행하세요.
                """
            )
        default:
            nil
        }
    }
}
