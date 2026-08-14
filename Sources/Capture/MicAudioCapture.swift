import AudioToolbox
import AVFoundation
import CoreAudio
import Foundation

/// 마이크 TCC 권한 게이트 — AVAudioEngine inputNode 접근 전 반드시 경유해야 한다.
/// 권한 없이 inputNode로 입력을 시도하면 엔진이 예외를 던질 수 있음(AVAudioEngine.h 명시).
enum MicPermission {
    static func ensureGranted() async throws {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return
        case .denied:
            throw CaptureError.microphoneDenied
        case .undetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            guard granted else { throw CaptureError.microphoneDenied }
        @unknown default:
            throw CaptureError.microphoneDenied
        }
    }
}

/// AVAudioEngine 마이크 캡처 소스 (P1-T4).
/// - local(본인) 트랙, 허드웨어 네이티브 샘플레이트(모노 다운믹스)
/// - 청크 단위는 100ms(FileAudioSource·SystemAudioCapture와 동일 계약)
/// - 권한 거부·포맷 이상 → CaptureError 종료. 조용한 실패 금지(§5)
public struct MicAudioCapture: AudioSource {
    /// 마이크 트랙 태그 — 인스턴스 생성(권한) 없이도 태깅 계약을 검증할 수 있게 정적 노출.
    public static let trackTag = AudioTrack.local

    public let track = AudioTrack.local
    /// 허드웨어 네이티브 샘플레이트 — init 시점에 권한 확인 후 조회한다.
    public let sampleRate: Int
    /// init 시점의 기본 입력 장치를 스냅샷으로 고정 — chunks() 실행 시점에 "지금 기본 입력이
    /// 뭔지"를 다시 조회하지 않는다. BlackHoleAudioCapture와 동시에 실시간 캡처가 시작되면
    /// 그쪽이 시스템 기본 입력을 BlackHole로 바꾸는데, 이 트랙이 매번 "현재 기본 입력"을
    /// 다시 조회했을 때 그 전환 타이밍과 겹치면 포맷 불일치로 캡처가 실패하거나(실측:
    /// captureFailed stage=micFormat) 최악의 경우 이 트랙이 실제로는 BlackHole을 잡아버려
    /// "나" 자막이 상대방 오디오를 그대로 복제하는 문제가 실측으로 재현됐다. 장치 ID를 한 번
    /// 고정해 AVAudioEngine 입력 노드를 그 장치에 직접 pin하면, 세션 도중 시스템 기본 입력이
    /// 바뀌어도 이 트랙은 영향받지 않는다.
    private let deviceID: AudioDeviceID

    /// 권한 확인 → 입력 장치 스냅샷 → 그 장치에 pin한 입력 포맷 조회. 권한 없으면 typed error.
    public init() async throws {
        try await MicPermission.ensureGranted()
        guard let deviceID = getDefaultInputDeviceID() else {
            throw CaptureError.captureFailed(detail: "stage=micInit code=noDefaultDevice")
        }
        self.deviceID = deviceID
        let engine = AVAudioEngine()
        try Self.pin(engine.inputNode, to: deviceID)
        let format = engine.inputNode.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw CaptureError.captureFailed(detail: "stage=micInit code=noInputFormat")
        }
        sampleRate = Int(format.sampleRate)
    }

    /// 호출마다 새 캡처 세션을 시작한다. 소비자 취소·반복 종료 시 엔진도 정지된다.
    public func chunks() -> AsyncThrowingStream<AudioChunk, any Error> {
        AsyncThrowingStream(bufferingPolicy: .unbounded) { continuation in
            let engine = MicCaptureEngine(continuation: continuation, sampleRate: sampleRate, deviceID: deviceID)
            let startTask = Task {
                do {
                    try await engine.start()
                    // 시작 완료 직후 소비자가 이미 종료한 경우 — 엔진을 방치하지 않는다.
                    if Task.isCancelled {
                        engine.stop()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                startTask.cancel()
                Task { engine.stop() }
            }
        }
    }

    /// AVAudioEngine의 입력 노드를 특정 CoreAudio 장치에 고정한다 — 이후 시스템 기본 입력이
    /// 바뀌어도(BlackHoleAudioCapture 등) 이 노드는 계속 지정한 장치만 캡처한다.
    fileprivate static func pin(_ node: AVAudioInputNode, to deviceID: AudioDeviceID) throws {
        guard let audioUnit = node.audioUnit else {
            throw CaptureError.captureFailed(detail: "stage=micInit code=noAudioUnit")
        }
        var device = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &device,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw CaptureError.captureFailed(detail: "stage=micInit code=setDeviceFailed status=\(status)")
        }
    }
}

/// AVAudioEngine 수명주기 + 탭 버퍼 디코딩.
/// 가변 상태(accumulator·stopped)는 NSLock으로 보호 — 탭 콜백은 오디오 콜백 경계(§5 예외)지만
/// 스레드를 소유할 수 없어 SCK 엔진(callbackQueue 한정)과 다른 동기화 수단을 쓴다.
private final class MicCaptureEngine: @unchecked Sendable {
    private let continuation: AsyncThrowingStream<AudioChunk, any Error>.Continuation
    private let expectedSampleRate: Int
    private let deviceID: AudioDeviceID
    private let lock = NSLock()
    private let engine = AVAudioEngine()
    private var accumulator: ChunkAccumulator
    private var stopped = false
    /// 오디오 장치 재구성(라우트 변경) 시 AVAudioEngine이 탭에 더 이상 버퍼를 넘기지 않게
    /// 되는 문제 대응 — deinit·stop()에서 해제해야 하므로 보관.
    private var configChangeObserver: NSObjectProtocol?

    init(
        continuation: AsyncThrowingStream<AudioChunk, any Error>.Continuation,
        sampleRate: Int,
        deviceID: AudioDeviceID
    ) {
        self.continuation = continuation
        expectedSampleRate = sampleRate
        self.deviceID = deviceID
        accumulator = ChunkAccumulator(track: .local, sampleRate: sampleRate)
    }

    deinit {
        if let configChangeObserver {
            NotificationCenter.default.removeObserver(configChangeObserver)
        }
        engine.stop() // stop() 미경로 방치 방지 — 시작 안 한 엔진의 stop은 무해
    }

    func start() async throws {
        try await MicPermission.ensureGranted()
        try installTapAndStart()

        // 실통화 중 탭이 몇 초 뒤 조용히 죽는 문제가 실측으로 재현됐다 — 에러도 스트림 종료도
        // 없이 handle()이 그냥 더 안 불림(REC는 계속 돌지만 새 자막이 안 뜸). 원인은 macOS가
        // 통화 오디오 세션 협상 등으로 오디오 그래프를 재구성할 때 AVAudioEngine이 이 알림을
        // 보내는데, 앱이 응답해서 탭을 다시 걸지 않으면 엔진은 "실행 중" 상태로 남아있지만
        // 입력 노드가 더 이상 버퍼를 전달하지 않는다(Apple 문서가 명시하는 필수 대응 — 이전
        // 코드에는 이 처리가 아예 없었음). 알림을 받으면 탭을 다시 걸고 엔진을 재시작한다.
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Task { self.reconfigureAfterRouteChange() }
        }
    }

    private func installTapAndStart() throws {
        let input = engine.inputNode
        try MicAudioCapture.pin(input, to: deviceID)
        let format = input.inputFormat(forBus: 0)
        // init 스냅샷 이후로 이 장치 자체의 포맷이 바뀌었다면(예: 하드웨어 재구성) 계약
        // (sampleRate) 위반 — 명시 실패. deviceID를 pin했으므로 "다른 장치가 기본이 됐다"는
        // 이유로는 더 이상 여기 걸리지 않는다.
        guard Int(format.sampleRate) == expectedSampleRate, format.channelCount > 0 else {
            throw CaptureError.captureFailed(detail: "stage=micFormat code=mismatch")
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.handle(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw CaptureError.captureFailed(detail: "stage=micStart code=\((error as NSError).code)")
        }
    }

    /// 라우트 변경 알림 후 탭을 다시 걸고 엔진을 재시작한다. 실패하면 조용히 멎어있는 것보다
    /// 명시적으로 스트림을 끝내는 게 낫다(§5).
    private func reconfigureAfterRouteChange() {
        lock.lock()
        let alreadyStopped = stopped
        lock.unlock()
        guard !alreadyStopped else { return }

        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        do {
            try installTapAndStart()
        } catch {
            continuation.finish(throwing: error)
        }
    }

    /// 엔진 정지 + 잔여 버퍼(<100ms) 방출. 중복 호출 안전.
    func stop() {
        lock.lock()
        guard !stopped else {
            lock.unlock()
            return
        }
        stopped = true
        lock.unlock()

        if let configChangeObserver {
            NotificationCenter.default.removeObserver(configChangeObserver)
            self.configChangeObserver = nil
        }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)

        lock.lock()
        let tail = accumulator.flush(capturedAt: Date())
        lock.unlock()
        if let tail {
            continuation.yield(tail)
        }
        continuation.finish()
    }

    /// 탭 콜백(오디오 콜백 경계) — 모노 다운믹스 후 청크 조립.
    private func handle(_ buffer: AVAudioPCMBuffer) {
        guard let samples = Self.decodeMono(buffer) else {
            continuation.finish(throwing: CaptureError.captureFailed(detail: "stage=micDecode code=unsupportedFormat"))
            return
        }
        lock.lock()
        guard !stopped else {
            lock.unlock()
            return
        }
        let chunks = accumulator.feed(samples, capturedAt: Date())
        lock.unlock()
        for chunk in chunks {
            continuation.yield(chunk)
        }
    }

    /// PCM float32 탭 버퍼 → 모노 정규화 샘플(채널 평균).
    private static func decodeMono(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return [] }
        guard let channelData = buffer.floatChannelData else { return nil }
        let channels = Int(buffer.format.channelCount)
        guard channels > 0 else { return nil }

        var samples = [Float]()
        samples.reserveCapacity(frameCount)
        for frame in 0 ..< frameCount {
            var sum: Float = 0
            for channel in 0 ..< channels {
                sum += channelData[channel][frame]
            }
            samples.append(sum / Float(channels))
        }
        return samples
    }
}
