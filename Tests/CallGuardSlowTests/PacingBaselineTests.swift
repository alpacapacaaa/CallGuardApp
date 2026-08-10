import Foundation
import Testing

/// 벽시계 페이싱 측정 기준선 검증 (P0-T3 FileAudioSource 실시간 페이싱 선행 점검, P0-T2).
/// 실패 조건: 요청 수면보다 경과 시간이 짧게 측정됨 → 페이싱이 실시간보다 앞서 방출될 위험.
/// 1초 이상 벽시계 소요이므로 느린 레인(CallGuardSlowTests) 소속 — ci_fast.sh에서 제외.
struct PacingBaselineTests {
    @Test func elapsedNeverRunsAheadOfRequestedSleep() {
        let clock = ContinuousClock()
        let start = clock.now
        Thread.sleep(forTimeInterval: 1.0)
        let elapsed = clock.now - start
        #expect(elapsed >= .milliseconds(950), "경과 시간 하한 위반: \(elapsed)")
        #expect(elapsed < .seconds(10), "비정상 지연: \(elapsed)")
    }
}
