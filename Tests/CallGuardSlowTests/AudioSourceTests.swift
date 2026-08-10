import Capture
import Foundation
import Testing
import TestSupport

/// P0-T3 DoD: 10s WAV 리플레이가 벽시계 9.5–10.5s 소요됨을 검증한다.
/// 벽시계 페이싱 테스트이므로 느린 레인(CallGuardSlowTests) 소속.
struct AudioSourceTests {
    @Test func tenSecondReplayTakesRealTime() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("callguard-replay-\(UUID()).wav")
        try WavSynth.pcm16(sampleRate: 16000, channels: 1, duration: 10).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let source = try FileAudioSource(url: url, track: .remote)
        #expect(source.sampleRate == 16000)
        #expect(source.track == .remote)

        let clock = ContinuousClock()
        let start = clock.now
        var firstChunkAt: ContinuousClock.Instant?
        var sampleCount = 0
        var chunkCount = 0
        var tracks = Set<AudioTrack>()
        for try await chunk in source.chunks() {
            if firstChunkAt == nil {
                firstChunkAt = clock.now
            }
            sampleCount += chunk.samples.count
            chunkCount += 1
            tracks.insert(chunk.track)
        }
        let elapsed = clock.now - start

        #expect(elapsed >= .seconds(9.5), "실시간보다 빠름(일괄 방출 의심): \(elapsed)")
        #expect(elapsed <= .seconds(10.5), "실시간 대비 과도한 지연: \(elapsed)")
        #expect(sampleCount == 160_000, "샘플 손실·중복: \(sampleCount)")
        #expect(chunkCount == 100, "청크 수 불일치: \(chunkCount)")
        #expect(tracks == [.remote])

        if let firstChunkAt {
            // 첫 청크가 페이싱 없이 즉시 나오면 일괄 방출 — 하한으로 차단
            #expect(firstChunkAt - start >= .milliseconds(80), "첫 청크 조기 방출")
        } else {
            Issue.record("방출된 청크가 없음")
        }
    }
}
