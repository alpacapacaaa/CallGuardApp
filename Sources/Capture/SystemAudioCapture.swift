import CoreGraphics
import CoreMedia
import Foundation
import ScreenCaptureKit

/// SCK 시스템 오디오 전용 캡처 소스 (P1-T2).
/// - 오디오 전용: 비디오 출력을 등록하지 않고 최소 표면(2×2) 구성 — G6, start() 주석 참조
/// - 48kHz PCM → AudioChunk(track: .remote), 청크 단위는 100ms(FileAudioSource와 동일 계약)
/// - 권한 거부·스트림 실패 → CaptureError 종료. 조용한 실패 금지(§5)
public struct SystemAudioCapture: AudioSource {
    /// 파이프라인 고정 샘플레이트 — SCK 구성과 WAV 저장에 그대로 사용한다.
    public static let systemSampleRate = 48000

    public let track = AudioTrack.remote
    public let sampleRate = Self.systemSampleRate

    public init() {}

    /// 호출마다 새 캡처 세션을 시작한다. 소비자 취소·반복 종료 시 스트림도 정지된다.
    public func chunks() -> AsyncThrowingStream<AudioChunk, any Error> {
        AsyncThrowingStream(bufferingPolicy: .unbounded) { continuation in
            let engine = SystemAudioEngine(continuation: continuation)
            let startTask = Task {
                do {
                    try await engine.start()
                    // 시작 완료 직후 소비자가 이미 종료한 경우 — 캡처 세션을 방치하지 않는다.
                    if Task.isCancelled {
                        await engine.stop()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                startTask.cancel()
                Task { await engine.stop() }
            }
        }
    }
}

/// SCStream 수명주기 + 오디오 샘플 버퍼 디코딩.
/// 가변 상태(accumulator)는 callbackQueue(오디오 콜백 경계 — §5 예외로 허용되는 유일한
/// DispatchQueue 사용 지점)와 순차적인 start/stop 경로에만 한정한다.
private final class SystemAudioEngine: NSObject, SCStreamDelegate, SCStreamOutput, @unchecked Sendable {
    private let continuation: AsyncThrowingStream<AudioChunk, any Error>.Continuation
    private let callbackQueue = DispatchQueue(label: "callguard.capture.system-audio")
    private var accumulator = ChunkAccumulator(track: .remote, sampleRate: SystemAudioCapture.systemSampleRate)
    private var stream: SCStream?

    init(continuation: AsyncThrowingStream<AudioChunk, any Error>.Continuation) {
        self.continuation = continuation
    }

    func start() async throws {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } catch {
            throw Self.captureError(from: error, stage: "shareableContent")
        }

        // SCDisplay에는 isMain이 없다 — CGMainDisplayID 매칭으로 메인 디스플레이 선택 (SDK 헤더 실측, P1-T2).
        let mainDisplayID = CGMainDisplayID()
        guard let display = content.displays.first(where: { $0.displayID == mainDisplayID })
            ?? content.displays.first
        else {
            throw CaptureError.captureFailed(detail: "stage=display code=noDisplayList")
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        // G6: SCK에는 비디오 캡처 완전 비활성화 속성이 없다 — 0×0 구성은 -3812로 거부됨(실측).
        // 따라서 최소 표면(2×2)·커서 없음·사실상 0 프레임으로 구성하고, 비디오 출력(.screen)은
        // 등록하지 않아 비디오 프레임이 프로세스로 전달되는 경로 자체를 만들지 않는다.
        configuration.width = 2
        configuration.height = 2
        configuration.showsCursor = false
        configuration.minimumFrameInterval = CMTimeMake(value: 3600, timescale: 1)
        configuration.sampleRate = SystemAudioCapture.systemSampleRate
        configuration.channelCount = 1

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        do {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: callbackQueue)
            try await stream.startCapture()
        } catch {
            throw Self.captureError(from: error, stage: "startCapture")
        }
        self.stream = stream
    }

    /// 스트림 정지 + 잔여 버퍼(<100ms) 방출. 중복 호출 안전.
    func stop() async {
        guard let stream else { return }
        self.stream = nil
        try? await stream.stopCapture()
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            callbackQueue.async {
                if let tail = self.accumulator.flush(capturedAt: Date()) {
                    self.continuation.yield(tail)
                }
                self.continuation.finish()
                done.resume()
            }
        }
    }

    // MARK: - SCStreamDelegate

    func stream(_: SCStream, didStopWithError error: any Error) {
        let nsError = error as NSError
        if nsError.domain == SCStreamErrorDomain, nsError.code == SCStreamError.userStopped.rawValue {
            continuation.finish()
            return
        }
        // 로그·오류 상세는 원인 코드·단계만 (G1 — 내용 유출 경로 차단).
        continuation.finish(throwing: CaptureError.captureFailed(detail: "stage=stream code=\(nsError.code)"))
    }

    // MARK: - SCStreamOutput

    func stream(_: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return } // 오디오 외 출력은 취급하지 않는다 (G6)
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        guard let samples = Self.decodeMono(sampleBuffer) else {
            continuation.finish(throwing: CaptureError.captureFailed(detail: "stage=decode code=unsupportedFormat"))
            return
        }
        for chunk in accumulator.feed(samples, capturedAt: Date()) {
            continuation.yield(chunk)
        }
    }

    // MARK: - 오류 매핑·디코딩

    private static func captureError(from error: any Error, stage: String) -> CaptureError {
        let nsError = error as NSError
        if nsError.domain == SCStreamErrorDomain, nsError.code == SCStreamError.userDeclined.rawValue {
            return .screenCaptureDenied
        }
        return .captureFailed(detail: "stage=\(stage) code=\(nsError.code)")
    }

    /// 오디오 샘플 버퍼 → 모노 정규화 샘플. 지원: 리틀엔디언 PCM Float32·Int16.
    /// 구성과 다른 포맷·샘플레이트는 nil — 호출 측이 명시 실패로 전환한다.
    private static func decodeMono(_ sampleBuffer: CMSampleBuffer) -> [Float]? {
        guard let (asbd, isFloat32) = validatedFormat(of: sampleBuffer) else { return nil }
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frameCount > 0 else { return [] }
        guard let audioData = retainedAudioData(of: sampleBuffer) else { return nil }

        let channels = Int(asbd.mChannelsPerFrame)
        let frameBytes = Int(asbd.mBytesPerFrame)
        let sampleBytes = frameBytes / channels
        guard audioData.byteCount >= frameCount * frameBytes else { return nil }

        var samples = [Float]()
        samples.reserveCapacity(frameCount)
        for frame in 0 ..< frameCount {
            var sum: Float = 0
            for channel in 0 ..< channels {
                let offset = frame * frameBytes + channel * sampleBytes
                sum += isFloat32
                    ? audioData.base.load(fromByteOffset: offset, as: Float.self)
                    : Float(Int16(bitPattern: audioData.base.load(fromByteOffset: offset, as: UInt16.self))) / 32768
            }
            samples.append(sum / Float(channels))
        }
        _ = audioData.blockBuffer // 데이터 포인터의 근거 수명 — 루프 동안 블록 버퍼 해제 방지
        return samples
    }

    /// 파이프라인 계약(48kHz 리틀엔디언 PCM, Float32 또는 Int16) 검증 — 위반 시 nil.
    private static func validatedFormat(of sampleBuffer: CMSampleBuffer) -> (AudioStreamBasicDescription, Bool)? {
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(format)
        else { return nil }
        let asbd = asbdPointer.pointee
        let isFloat32 = asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 && asbd.mBitsPerChannel == 32
        let isInt16 = asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0 && asbd.mBitsPerChannel == 16
        guard asbd.mFormatID == kAudioFormatLinearPCM,
              asbd.mFormatFlags & kAudioFormatFlagIsBigEndian == 0,
              asbd.mSampleRate == Double(SystemAudioCapture.systemSampleRate),
              asbd.mChannelsPerFrame >= 1,
              asbd.mBytesPerFrame > 0,
              isFloat32 || isInt16
        else { return nil }
        return (asbd, isFloat32)
    }

    /// 오디오 버퍼 데이터 포인터 + 근거 CMBlockBuffer + 바이트 수.
    /// 모노 구성 — 버퍼 1개를 보장받는다. 그 외 배치는 구성 위반이므로 nil.
    private static func retainedAudioData(of sampleBuffer: CMSampleBuffer) -> RetainedAudioData? {
        let listSize = MemoryLayout<AudioBufferList>.stride
        let listMemory = UnsafeMutableRawPointer.allocate(byteCount: listSize, alignment: 16)
        defer { listMemory.deallocate() }
        let list = listMemory.bindMemory(to: AudioBufferList.self, capacity: 1)
        list.pointee.mNumberBuffers = 0
        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil, // 고정 레이아웃(모노, 버퍼 1개) 사용
            bufferListOut: list,
            bufferListSize: listSize,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr, let blockBuffer, list.pointee.mNumberBuffers == 1,
              let base = list.pointee.mBuffers.mData
        else { return nil }
        return RetainedAudioData(
            base: base,
            byteCount: Int(list.pointee.mBuffers.mDataByteSize),
            blockBuffer: blockBuffer
        )
    }

    /// 디코딩 구간 동안 유지되어야 하는 오디오 버퍼 메모리 묶음.
    private struct RetainedAudioData {
        let base: UnsafeMutableRawPointer
        let byteCount: Int
        let blockBuffer: CMBlockBuffer
    }
}
