@testable import Capture
import Foundation
import Testing

/// SCK 캡처 경로 단위 검증 — 실제 캡처 없이(권한 불필요, fast 레인) 계약만 검증.
/// 실기기 캡처·재생 확인은 운영자 스모크 항목(P1-T2 DoD).
struct SystemAudioCaptureTests {
    @Test func contractMatchesPipeline() {
        let source = SystemAudioCapture()
        #expect(source.track == .remote) // SCK 시스템 오디오 = 상대방 트랙(AGENTS.md §4)
        #expect(source.sampleRate == 48000)
        let asProtocol: any AudioSource = source
        #expect(asProtocol.sampleRate == SystemAudioCapture.systemSampleRate)
    }
}

struct ChunkAccumulatorTests {
    @Test func emitsChunksOnHundredMsBoundary() {
        var accumulator = ChunkAccumulator(track: .remote, sampleRate: 48000)
        #expect(accumulator.chunkFrames == 4800) // FileAudioSource.chunkDuration(100ms) 계약

        let capturedAt = Date()
        var chunks = accumulator.feed(Array(repeating: 0.25, count: 3000), capturedAt: capturedAt)
        #expect(chunks.isEmpty)

        chunks = accumulator.feed(Array(repeating: 0.25, count: 3000), capturedAt: capturedAt)
        #expect(chunks.count == 1)
        #expect(chunks[0].samples.count == 4800)
        #expect(chunks[0].track == .remote)
        #expect(chunks[0].sampleRate == 48000)
        #expect(chunks[0].capturedAt == capturedAt)

        // pending 1200 + 신규 10000 = 11200 → 청크 2개, 잔여 1600
        chunks = accumulator.feed(Array(repeating: 0.25, count: 10000), capturedAt: capturedAt)
        #expect(chunks.count == 2)
        #expect(chunks.allSatisfy { $0.samples.count == 4800 })
        #expect(accumulator.pending.count == 1600)
    }

    @Test func flushEmitsRemainderOnce() {
        var accumulator = ChunkAccumulator(track: .local, sampleRate: 48000)
        #expect(accumulator.flush(capturedAt: Date()) == nil)

        _ = accumulator.feed([0.1, 0.2, 0.3], capturedAt: Date())
        let tail = accumulator.flush(capturedAt: Date())
        #expect(tail?.samples == [0.1, 0.2, 0.3])
        #expect(tail?.track == .local)
        #expect(tail?.samples.count ?? 0 < 4800)
        #expect(accumulator.flush(capturedAt: Date()) == nil) // 2회 flush는 없음
    }

    @Test func emptyFeedIsNoOp() {
        var accumulator = ChunkAccumulator(track: .remote, sampleRate: 48000)
        #expect(accumulator.feed([], capturedAt: Date()).isEmpty)
        #expect(accumulator.pending.isEmpty)
    }

    @Test func preservesTotalSampleCountAcrossIrregularFeeds() {
        var accumulator = ChunkAccumulator(track: .remote, sampleRate: 48000)
        var emitted = 0
        for _ in 0 ..< 7 {
            let chunks = accumulator.feed(Array(repeating: 0, count: 1999), capturedAt: Date())
            emitted += chunks.reduce(0) { $0 + $1.samples.count }
        }
        emitted += accumulator.flush(capturedAt: Date())?.samples.count ?? 0
        #expect(emitted == 7 * 1999)
    }
}
