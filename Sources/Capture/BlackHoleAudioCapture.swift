import AVFoundation
import CoreAudio
import Foundation

/// BlackHole 가상 오디오 장치를 통한 시스템 오디오 캡처 (P1-T2 폴백).
/// - SCK가 전화 통화 오디오를 캡처하지 못하는 macOS 제한을 우회
/// - 사용자가 BlackHole 설치 + Multi-Output Device 설정 필요
/// - AVAudioEngine으로 BlackHole 입력을 캡처 (AUHAL은 BlackHole과 호환 불가)
/// - 48kHz PCM → AudioChunk(track: .remote), 청크 단위는 100ms
public struct BlackHoleAudioCapture: AudioSource {
    public static let deviceName = "BlackHole 2ch"
    public static let systemSampleRate = 48000

    public let track = AudioTrack.remote
    public let sampleRate = Self.systemSampleRate

    public init() {}

    /// BlackHole 장치가 시스템에 설치되어 있는지 확인.
    public static func isAvailable() -> Bool {
        findBlackHoleDeviceID() != nil
    }

    public func chunks() -> AsyncThrowingStream<AudioChunk, any Error> {
        AsyncThrowingStream(bufferingPolicy: .unbounded) { continuation in
            let engine = BlackHoleCaptureEngine(continuation: continuation, sampleRate: sampleRate)
            let startTask = Task {
                do {
                    try await engine.start()
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
}

/// AVAudioEngine으로 BlackHole 장치의 오디오를 캡처하는 엔진.
/// AUHAL API는 BlackHole 드라이버와 호환되지 않아 콜백이 오지 않으므로,
/// AVAudioEngine + 기본 입력 장치 임시 변경 방식을 사용한다.
private final class BlackHoleCaptureEngine: @unchecked Sendable {
    private let continuation: AsyncThrowingStream<AudioChunk, any Error>.Continuation
    private let expectedSampleRate: Int
    private let lock = NSLock()
    private var accumulator: ChunkAccumulator
    private var stopped = false
    private var audioEngine: AVAudioEngine?
    private var originalInputDevice: AudioDeviceID?
    /// 오디오 장치 재구성(라우트 변경) 시 AVAudioEngine이 탭에 더 이상 버퍼를 넘기지 않게
    /// 되는 문제 대응 — deinit·stop()에서 해제해야 하므로 보관.
    private var configChangeObserver: NSObjectProtocol?
    // TEMP DEBUG(2026-08-12) — "상대방" 트랙이 통째로 무자막인 원인 진단용. 원인 확정 후 제거.
    private var debugCallbackCount = 0

    init(continuation: AsyncThrowingStream<AudioChunk, any Error>.Continuation, sampleRate: Int) {
        self.continuation = continuation
        expectedSampleRate = sampleRate
        accumulator = ChunkAccumulator(track: .remote, sampleRate: sampleRate)
    }

    deinit {
        stop()
    }

    /// start()는 동기 CoreAudio/AVAudioEngine 호출이라 중간에 취소를 반영하지 못하고 끝까지
    /// 실행된다 — 그런데 태스크 그룹의 다른 트랙(예: 마이크)이 먼저 실패해 이 스트림이 취소되면
    /// stop()이 start()보다 먼저 끝나 stopped=true를 세팅해버리는 레이스가 실측으로 재현됐다.
    /// 그 상태에서 뒤늦게 start()가 디바이스 전환·엔진 기동을 끝내면, 그 결과물(실행 중인
    /// 엔진 + BlackHole로 바뀐 시스템 기본 입력)을 아무도 정리하지 않아 앱이 종료될 때까지
    /// 마이크가 시스템 전역에서 BlackHole에 고정된 채로 남았다. 시작 전/후 모두 stopped를
    /// 확인해, 늦게 끝난 start()가 스스로 방금 만든 것을 되돌리게 한다.
    func start() async throws {
        guard !isStopped() else { return }

        guard let deviceID = findBlackHoleDeviceID() else {
            throw CaptureError.captureFailed(detail: "stage=blackholeInit code=deviceNotFound")
        }
        debugLog("device found id=\(deviceID)")

        // 현재 기본 입력 장치를 저장하고 BlackHole로 임시 변경
        let savedInputDevice = getDefaultInputDeviceID()
        guard setDefaultInputDeviceID(deviceID) else {
            throw CaptureError.captureFailed(detail: "stage=blackholeInit code=setDefaultInputFailed")
        }
        debugLog("default input switched to BlackHole (was \(savedInputDevice.map(String.init) ?? "nil"))")

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        // setDefaultInputDeviceID 직후 곧바로 inputFormat(forBus:)를 읽으면 CoreAudio가 아직
        // 전환을 전파하기 전이라 sampleRate=0인 무효 포맷이 실측으로 관찰됨 — installTap에
        // 그 포맷을 그대로 넘기면 Swift로 못 잡는 ObjC NSException(IsFormatSampleRateAnd
        // ChannelCountValid)이 던져져 프로세스 전체가 죽는다. 전환이 반영될 때까지 짧게 재시도.
        let inputFormat: AVAudioFormat
        do {
            inputFormat = try await Self.waitForValidFormat(node: inputNode)
        } catch {
            if let savedInputDevice {
                _ = setDefaultInputDeviceID(savedInputDevice)
            }
            throw error
        }

        debugLog("input format sampleRate=\(inputFormat.sampleRate) channels=\(inputFormat.channelCount)")
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.handleAudio(buffer: buffer)
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            if let savedInputDevice {
                _ = setDefaultInputDeviceID(savedInputDevice)
            }
            throw CaptureError.captureFailed(detail: "stage=blackholeStart code=engineStartFailed")
        }
        debugLog("engine started, isRunning=\(engine.isRunning)")

        // stop()이 엔진 기동 도중 먼저 실행돼 "정리할 게 없다"고 보고 끝났던 경우 — 방금 만든
        // 엔진과 디바이스 전환을 여기서 직접 되돌린다.
        guard commitIfNotStopped(engine: engine, originalInputDevice: savedInputDevice) else {
            engine.stop()
            inputNode.removeTap(onBus: 0)
            if let savedInputDevice {
                _ = setDefaultInputDeviceID(savedInputDevice)
            }
            return
        }

        // 실통화 중 탭이 몇 초 뒤 조용히 죽는 문제가 실측으로 재현됐다 — 에러도 스트림 종료도
        // 없이 handleAudio()가 그냥 더 안 불림(REC는 계속 돌지만 새 자막이 안 뜸). macOS가
        // 통화 오디오 세션 협상 등으로 오디오 그래프를 재구성할 때(라우트 변경 포함) 이 알림을
        // 보내는데, 앱이 응답해서 탭을 다시 걸지 않으면 엔진은 "실행 중" 상태로 남아있지만
        // 입력 노드가 더 이상 버퍼를 전달하지 않는다(Apple 문서가 명시하는 필수 대응 — 이전
        // 코드에는 이 처리가 아예 없었음). BlackHole은 기본 입력 장치를 직접 바꿔 쓰므로,
        // 통화 쪽이 그 사이 기본 입력을 되돌렸을 가능성까지 함께 확인해 되돌린다.
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.reconfigureAfterRouteChange() }
        }
    }

    /// 라우트 변경 알림 후 BlackHole이 여전히 기본 입력인지 확인하고, 탭을 다시 걸어 엔진을
    /// 재시작한다. 실패하면 조용히 멎어있는 것보다 명시적으로 스트림을 끝내는 게 낫다(§5).
    private func reconfigureAfterRouteChange() async {
        guard let engine = activeEngineIfNotStopped() else { return }

        guard let deviceID = findBlackHoleDeviceID() else {
            continuation.finish(throwing: CaptureError.captureFailed(detail: "stage=blackholeReconfig code=deviceGone"))
            return
        }
        if getDefaultInputDeviceID() != deviceID {
            _ = setDefaultInputDeviceID(deviceID)
        }

        engine.stop()
        engine.inputNode.removeTap(onBus: 0)

        do {
            let inputFormat = try await Self.waitForValidFormat(node: engine.inputNode)
            engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                self?.handleAudio(buffer: buffer)
            }
            try engine.start()
        } catch {
            continuation.finish(throwing: CaptureError.captureFailed(detail: "stage=blackholeReconfig code=restartFailed"))
        }
    }

    /// 기본 입력 장치 전환 직후 inputFormat(forBus:)가 유효해질 때까지 재시도(최대 2초 —
    /// 실측으로 200ms는 이 기기에서 매번 부족했고 2초 예산 안에서는 항상 안정적으로 유효한
    /// 포맷을 받음). 그래도 무효면 명시적 실패로 알린다 — installTap에 무효 포맷을 넘겨
    /// 프로세스가 죽게 두지 않는다.
    private static func waitForValidFormat(
        node: AVAudioInputNode,
        attempts: Int = 40,
        delayNanoseconds: UInt64 = 50_000_000
    ) async throws -> AVAudioFormat {
        for _ in 0 ..< attempts {
            let format = node.inputFormat(forBus: 0)
            if format.sampleRate > 0, format.channelCount > 0 {
                return format
            }
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        throw CaptureError.captureFailed(detail: "stage=blackholeInit code=invalidFormatAfterSwitch")
    }

    private func isStopped() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }

    /// async 컨텍스트에서 NSLock을 직접 호출하는 건 Swift 6 언어 모드에서 컴파일 에러가
    /// 되므로(lock/unlock이 비동기 컨텍스트에서 unavailable), 동기 헬퍼로 스냅샷만 떠서
    /// 반환한다.
    private func activeEngineIfNotStopped() -> AVAudioEngine? {
        lock.lock()
        defer { lock.unlock() }
        return stopped ? nil : audioEngine
    }

    /// stopped가 아직 false면 방금 시작한 엔진을 인스턴스 상태로 채택하고 true를 반환한다.
    /// 이미 stopped라면(레이스로 stop()이 먼저 끝난 경우) 아무 상태도 바꾸지 않고 false를
    /// 반환 — 호출자가 스스로 되돌려야 함을 알린다.
    private func commitIfNotStopped(engine: AVAudioEngine, originalInputDevice: AudioDeviceID?) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !stopped else { return false }
        self.originalInputDevice = originalInputDevice
        audioEngine = engine
        return true
    }

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
        if let engine = audioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil

        restoreInputDevice()

        lock.lock()
        let tail = accumulator.flush(capturedAt: Date())
        lock.unlock()
        if let tail {
            continuation.yield(tail)
        }
        continuation.finish()
    }

    private func handleAudio(buffer: AVAudioPCMBuffer) {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)

        // 모노 다운믹스: 다채널이면 평균
        var samples = [Float]()
        samples.reserveCapacity(frameCount)
        for frame in 0 ..< frameCount {
            var sum: Float = 0
            for channel in 0 ..< channelCount {
                sum += channelData[channel][frame]
            }
            samples.append(sum / Float(channelCount))
        }

        debugCallbackCount += 1
        if debugCallbackCount % 12 == 0 { // ~1초 간격(4096프레임@48kHz≈85ms)
            let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
            debugLog("tap alive callback#\(debugCallbackCount) frames=\(frameCount) peak=\(peak)")
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

    private func restoreInputDevice() {
        if let original = originalInputDevice {
            _ = setDefaultInputDeviceID(original)
            originalInputDevice = nil
        }
    }
}

// TEMP DEBUG(2026-08-12) — "상대방" 트랙 무자막 원인 진단용. 원인 확정 후 제거.
public func debugLog(_ message: String, tag: String = "BlackHole") {
    FileHandle.standardError.write("[\(tag)] \(message)\n".data(using: .utf8)!)
}

// MARK: - CoreAudio Helpers

private func findBlackHoleDeviceID() -> AudioDeviceID? {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var dataSize: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize
    ) == noErr else { return nil }
    let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
    var ids = [AudioDeviceID](repeating: 0, count: count)
    guard AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize, &ids
    ) == noErr else { return nil }
    for id in ids {
        var naddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var nsize = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(id, &naddr, 0, nil, &nsize, &name) == noErr else { continue }
        if (name as String).contains(BlackHoleAudioCapture.deviceName) {
            return id
        }
    }
    return nil
}

/// internal(파일 범위 아님) — MicAudioCapture도 동일한 "지금 기본 입력이 뭔지" 조회가
/// 필요해 공유한다(중복 구현 시 조회 시점이 어긋나 레이스가 재발할 여지가 생김).
func getDefaultInputDeviceID() -> AudioDeviceID? {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var deviceID: AudioDeviceID = 0
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID
    ) == noErr else { return nil }
    return deviceID
}

private func setDefaultInputDeviceID(_ deviceID: AudioDeviceID) -> Bool {
    var addr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var dev = deviceID
    return AudioObjectSetPropertyData(
        AudioObjectID(kAudioObjectSystemObject), &addr,
        0, nil,
        UInt32(MemoryLayout<AudioDeviceID>.size), &dev
    ) == noErr
}
