import AlertPolicy
import AppKit
import CallGuardUI
import Capture
import Detection
import Foundation
import Session
import STT

struct TranscriptLogEntry: Identifiable {
    let id = UUID()
    let track: AudioTrack
    let timestamp: String
    let level: AlertLevel
    let text: String
}

@MainActor
@Observable
final class AppState {
    private(set) var sessionController = SessionController()
    private(set) var alertLevel: AlertLevel = .none
    private(set) var currentScore: RiskScore?
    private(set) var statusMessage = "동의 후 통화 녹음 파일을 선택하세요"
    private(set) var isPlaying = false
    private(set) var transcriptLog: [TranscriptLogEntry] = []

    private var playbackTask: Task<Void, Never>?
    private var localCaptureTask: Task<Void, Never>?
    private var policyActor: PolicyActor?
    private var dangerWindow: DangerWindowController?
    /// SessionController는 idle→active→ended 1회용 상태머신(P4-T1 설계, 재사용 불가 —
    /// SessionControllerTests.eventsAfterEndedAreIgnored가 이 계약을 고정한다). 앱은 여러 번
    /// 캡처를 시작/중지할 수 있어야 하므로 세션마다 새 인스턴스를 만들되, 동의는 앱 레벨에서
    /// 별도로 기억해 매번 다시 묻지 않는다(G7은 "최초 1회 필수"로 충족 — 완전 생략은 아님).
    private var hasEverConsented = false

    var hasConsent: Bool {
        hasEverConsented
    }

    func grantConsent() {
        hasEverConsented = true
        sessionController.handle(.consentGranted)
        statusMessage = "동의 완료 — 파일을 선택하세요"
    }

    /// 파일 선택은 SwiftUI .fileImporter(뷰 쪽)로 처리한다 — AppKit NSOpenPanel을
    /// MenuBarExtra(.window) 팝업에서 직접 열면(runModal·begin 둘 다) 팝업 창의 임시(transient)
    /// 특성과 충돌해 폴더 탐색 중 패널이 닫히는 문제가 실측됐다. .fileImporter는 SwiftUI가
    /// 프레젠테이션을 직접 관리해 이 문제가 없다.
    func start(fileURL: URL) {
        guard let source = try? FileAudioSource(url: fileURL, track: .remote) else {
            statusMessage = "오디오 파싱 실패 — PCM WAV 형식인지 확인"
            return
        }
        begin(source: source, label: "재생 중: \(fileURL.lastPathComponent)")
    }

    /// 실시간 통화 캡처(F-C4). 상대방 오디오(SystemAudioCapture, remote)는 탐지까지 수행하고,
    /// 본인 마이크(MicAudioCapture, local)는 병렬로 전사만 해 화자 구분 표시에 쓴다 — rules.yaml
    /// 키워드가 전부 상대방(가해자) 발화 패턴이라 본인 트랙은 탐지 판정에 넣지 않는다.
    func startLiveCapture() {
        begin(source: SystemAudioCapture(), label: "실시간 캡처 중")
        localCaptureTask = Task { [weak self] in
            guard let mic = try? await MicAudioCapture() else { return }
            await runTranscriptionOnlyPipeline(source: mic) { segment in
                self?.appendLog(segment: segment, level: .none)
            }
        }
    }

    private func begin(source: any AudioSource, label: String) {
        if sessionController.state != .idle {
            sessionController = SessionController()
            if hasEverConsented {
                sessionController.handle(.consentGranted)
            }
        }
        sessionController.handle(.sourceStarted)
        guard sessionController.state == .active else {
            statusMessage = "세션 시작 실패(동의 확인 필요)"
            return
        }
        isPlaying = true
        alertLevel = .none
        currentScore = nil
        transcriptLog.removeAll()
        statusMessage = label

        let policyActor = PolicyActor()
        self.policyActor = policyActor

        playbackTask = Task { [weak self] in
            await runPipeline(
                source: source,
                policyActor: policyActor,
                onStatus: { message in self?.statusMessage = message },
                onSegment: { segment, score, level in self?.handle(segment: segment, score: score, level: level) },
                onFinished: { self?.finishNaturally() }
            )
        }
    }

    private func handle(segment: TranscriptSegment, score: RiskScore?, level: AlertLevel) {
        alertLevel = level
        currentScore = score
        appendLog(segment: segment, level: level)

        if level == .danger {
            let viewModel = AlertViewModel(level: level, score: score)
            if dangerWindow == nil {
                dangerWindow = DangerWindowController(viewModel: viewModel) { [weak self] in self?.dismissAlert() }
            }
            dangerWindow?.present()
        } else {
            dangerWindow?.close()
            dangerWindow = nil
        }
    }

    private func appendLog(segment: TranscriptSegment, level: AlertLevel) {
        transcriptLog.append(
            TranscriptLogEntry(
                track: segment.track, timestamp: String(format: "%.0fs", segment.endTime),
                level: level, text: segment.text
            )
        )
    }

    func dismissAlert() {
        guard let category = currentScore?.category, let policyActor else { return }
        dangerWindow?.close()
        dangerWindow = nil
        alertLevel = .none
        Task { await policyActor.dismiss(category: category) }
    }

    func stopPlayback() {
        playbackTask?.cancel()
        localCaptureTask?.cancel()
        sessionController.handle(.manualStopRequested)
        finish()
    }

    private func finishNaturally() {
        if sessionController.state == .active {
            sessionController.handle(.sourceEnded)
        }
        localCaptureTask?.cancel()
        finish()
    }

    private func finish() {
        isPlaying = false
        dangerWindow?.close()
        dangerWindow = nil
        statusMessage = "통화 종료 — 최종 판정: \(alertLevel == .none ? "정상" : alertLevel == .caution ? "주의" : "위험")"
    }
}
