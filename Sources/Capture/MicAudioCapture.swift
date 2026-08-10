import AVFoundation
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

    /// 권한 확인 → 입력 포맷 조회. 권한 없으면 여기서 typed error(inputNode 무접근).
    public init() async throws {
        try await MicPermission.ensureGranted()
        let engine = AVAudioEngine()
        let format = engine.inputNode.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw CaptureError.captureFailed(detail: "stage=micInit code=noInputFormat")
        }
        sampleRate = Int(format.sampleRate)
    }

    /// 호출마다 새 캡처 세션을 시작한다. 소비자 취소·반복 종료 시 엔진도 정지된다.
    public func chunks() -> AsyncThrowingStream<AudioChunk, any Error> {
        AsyncThrowingStream(bufferingPolicy: .unbounded) { continuation in
            let engine = MicCaptureEngine(continuation: continuation, sampleRate: sampleRate)
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
}

/// AVAudioEngine 수명주기 + 탭 버퍼 디코딩.
/// 가변 상태(accumulator·stopped)는 NSLock으로 보호 — 탭 콜백은 오디오 콜백 경계(§5 예외)지만
/// 스레드를 소유할 수 없어 SCK 엔진(callbackQueue 한정)과 다른 동기화 수단을 쓴다.
private final class MicCaptureEngine: @unchecked Sendable {
    private let continuation: AsyncThrowingStream<AudioChunk, any Error>.Continuation
    private let expectedSampleRate: Int
    private let lock = NSLock()
    private let engine = AVAudioEngine()
    private var accumulator: ChunkAccumulator
    private var stopped = false

    init(continuation: AsyncThrowingStream<AudioChunk, any Error>.Continuation, sampleRate: Int) {
        self.continuation = continuation
        expectedSampleRate = sampleRate
        accumulator = ChunkAccumulator(track: .local, sampleRate: sampleRate)
    }

    deinit {
        engine.stop() // stop() 미경로 방치 방지 — 시작 안 한 엔진의 stop은 무해
    }

    func start() async throws {
        try await MicPermission.ensureGranted()
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        // 세션 중 장치 변경으로 포맷이 달라지면 계약(sampleRate) 위반 — 명시 실패.
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

    /// 엔진 정지 + 잔여 버퍼(<100ms) 방출. 중복 호출 안전.
    func stop() {
        lock.lock()
        guard !stopped else {
            lock.unlock()
            return
        }
        stopped = true
        lock.unlock()

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
