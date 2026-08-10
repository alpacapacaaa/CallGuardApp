@testable import Capture
import Foundation
import Testing

/// P1-T5 "권한 미보유 시 크래시 없이 안내 상태 진입" 검증.
/// OS의 TCC 상태는 테스트에서 결정적으로 조작할 수 없으므로, 거부 시 도달하는
/// 안내 상태 매핑 자체(권한 오류 → exit·안내 / 그 외 → 일반 실패)를 순수 단위로 검증한다.
/// 매핑은 총함수라 어떤 CaptureError 입력에도 예외·크래시가 없어야 한다.
struct PermissionGuidanceTests {
    @Test func screenCaptureDeniedMapsToGuidanceExit3() {
        let guidance = PermissionGuidance.from(.screenCaptureDenied)
        #expect(guidance != nil, "화면녹화 거부는 안내 상태여야 한다")
        #expect(guidance?.exitCode == 3)
        #expect(guidance?.title.contains("화면녹화") == true)
        #expect(guidance?.instruction.isEmpty == false)
        #expect(guidance?.instruction.contains("화면 녹화") == true)
    }

    @Test func microphoneDeniedMapsToGuidanceExit4() {
        let guidance = PermissionGuidance.from(.microphoneDenied)
        #expect(guidance != nil, "마이크 거부는 안내 상태여야 한다")
        #expect(guidance?.exitCode == 4)
        #expect(guidance?.title.contains("마이크") == true)
        #expect(guidance?.instruction.isEmpty == false)
        #expect(guidance?.instruction.contains("마이크") == true)
    }

    @Test func permissionExitCodesAreDistinct() {
        let screen = PermissionGuidance.from(.screenCaptureDenied)
        let mic = PermissionGuidance.from(.microphoneDenied)
        #expect(screen?.exitCode != mic?.exitCode, "권한 종류별 종료코드는 원인 특정 가능해야 한다")
        #expect(screen?.exitCode != 0 && mic?.exitCode != 0, "권한 거부는 비제로 종료")
    }

    @Test func nonPermissionErrorsAreNotGuidance() {
        // 일반 실패는 안내 상태가 아니라 실패 경로(exit 1)로 가야 한다.
        let failures: [CaptureError] = [
            .captureFailed(detail: "stage=test code=1"),
            .wavWriteFailed(path: "/tmp/x.wav"),
            .fileReadFailed(path: "/tmp/x.wav"),
            .notWav,
            .truncated,
            .missingFormat,
            .missingData,
            .unsupportedFormat(detail: "format=0"),
        ]
        for failure in failures {
            #expect(PermissionGuidance.from(failure) == nil, "\(failure)는 권한 안내가 아니어야 한다")
        }
    }

    @Test func mappingIsTotalOverAllErrorCases() {
        // 모든 CaptureError 케이스를 순회해도 크래시·예외가 없어야 한다(총함수 계약).
        let allCases: [CaptureError] = [
            .screenCaptureDenied,
            .microphoneDenied,
            .captureFailed(detail: ""),
            .wavWriteFailed(path: ""),
            .fileReadFailed(path: ""),
            .notWav,
            .truncated,
            .missingFormat,
            .missingData,
            .unsupportedFormat(detail: ""),
        ]
        for error in allCases {
            // 결과가 nil이든 안내든, 호출 자체가 정상 완료되는 것이 핵심.
            _ = PermissionGuidance.from(error)
        }
    }
}
