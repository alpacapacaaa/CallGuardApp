@testable import Session
import Testing

struct SessionControllerTests {
    @Test func startsIdle() {
        #expect(SessionController().state == .idle)
    }

    /// F-M8 / G7: 동의 전에는 sourceStarted가 도착해도 파이프라인(active)로 전이하지 않는다.
    @Test func sourceStartedWithoutConsentIsIgnored() {
        var controller = SessionController()
        #expect(controller.handle(.sourceStarted) == .idle)
        #expect(!controller.hasConsent)
    }

    @Test func consentGrantedThenSourceStartedTransitionsToActive() {
        var controller = SessionController()
        controller.handle(.consentGranted)
        #expect(controller.hasConsent)
        #expect(controller.handle(.sourceStarted) == .active)
    }

    @Test func sourceEndedTransitionsActiveToEndedOfStream() {
        var controller = SessionController()
        controller.handle(.consentGranted)
        controller.handle(.sourceStarted)
        #expect(controller.handle(.sourceEnded) == .ended(.endOfStream))
    }

    @Test func manualStopTransitionsActiveToEndedManualStop() {
        var controller = SessionController()
        controller.handle(.consentGranted)
        controller.handle(.sourceStarted)
        #expect(controller.handle(.manualStopRequested) == .ended(.manualStop))
    }

    @Test func sourceEndedWhileIdleIsIgnored() {
        var controller = SessionController()
        #expect(controller.handle(.sourceEnded) == .idle)
    }

    @Test func manualStopWhileIdleIsIgnored() {
        var controller = SessionController()
        #expect(controller.handle(.manualStopRequested) == .idle)
    }

    @Test func eventsAfterEndedAreIgnored() {
        var controller = SessionController()
        controller.handle(.consentGranted)
        controller.handle(.sourceStarted)
        controller.handle(.sourceEnded)
        #expect(controller.handle(.sourceStarted) == .ended(.endOfStream))
        #expect(controller.handle(.manualStopRequested) == .ended(.endOfStream))
    }

    @Test func duplicateSourceStartedWhileActiveStaysActive() {
        var controller = SessionController()
        controller.handle(.consentGranted)
        controller.handle(.sourceStarted)
        #expect(controller.handle(.sourceStarted) == .active)
    }

    /// DoD: 재생 시작/EOF 이벤트 시퀀스 → 세션 시작/종료 전이 검증(동의는 사전 조건으로 부여).
    @Test func fullPlaybackLifecycleSequence() {
        var controller = SessionController()
        controller.handle(.consentGranted)
        var observed: [SessionState] = [controller.state]
        for event in [SessionEvent.sourceStarted, .sourceEnded] {
            observed.append(controller.handle(event))
        }
        #expect(observed == [.idle, .active, .ended(.endOfStream)])
    }
}
