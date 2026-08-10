import Foundation

/// 파일 리플레이 오디오 소스 (AGENTS.md §4 테스트 주입 + 데모·자가진단 공용).
/// WAV를 벽시계 실시간 페이싱으로 재방출한다 (AGENTS.md §7) —
/// 일괄 방출 금지: ContinuousClock 절대 스케줄 기준, 지연 누적 없음.
public struct FileAudioSource: AudioSource {
    /// 청크 하나에 해당하는 오디오 길이 — 100ms 단위 방출.
    public static let chunkDuration: TimeInterval = 0.1

    public let track: AudioTrack
    public let sampleRate: Int
    private let samples: [Float]

    /// 파일을 즉시 파싱·검증한다 — 불량 파일은 생성 시점에 typed error.
    public init(url: URL, track: AudioTrack) throws {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CaptureError.fileReadFailed(path: url.path)
        }
        let file = try WavFile.parse(data)
        self.track = track
        sampleRate = file.sampleRate
        samples = file.samples
    }

    public func chunks() -> AsyncThrowingStream<AudioChunk, any Error> {
        AsyncThrowingStream(bufferingPolicy: .unbounded) { continuation in
            let task = Task {
                let chunkSamples = max(1, Int((Double(sampleRate) * Self.chunkDuration).rounded()))
                let clock = ContinuousClock()
                let start = clock.now
                var offset = 0
                var chunkIndex = 0
                while offset < samples.count {
                    // 청크 종료 시점(실제 장치의 버퍼 완성 시점) 방출.
                    // 마감은 절대 시각 기준 — 지나간 마감은 즉시 방출해 드리프트를 쌓지 않는다.
                    let deadline = start + .seconds(Double(chunkIndex + 1) * Self.chunkDuration)
                    do { try await clock.sleep(until: deadline) } catch { return } // 취소 시 방출 중단
                    let upper = min(offset + chunkSamples, samples.count)
                    continuation.yield(AudioChunk(
                        track: track,
                        samples: Array(samples[offset ..< upper]),
                        sampleRate: sampleRate,
                        capturedAt: Date()
                    ))
                    offset = upper
                    chunkIndex += 1
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
