@testable import Capture
import Foundation
import Testing

/// P1-T4 트랙 태깅 검증 — 캡처 소스↔트랙↔산출 파일명 계약.
/// 권한·하드웨어 없이 검증 가능한 태깅 규약만 다룬다(fast 레인).
struct TrackTaggingTests {
    @Test func captureFileNamesAreFixedPerTrack() {
        #expect(AudioTrack.remote.captureFileName == "remote.wav")
        #expect(AudioTrack.local.captureFileName == "local.wav")
        // 트랙 추가 시 파일명 규약도 함께 검토하도록 전수 커버.
        #expect(AudioTrack.allCases.map(\.captureFileName) == ["remote.wav", "local.wav"])
    }

    @Test func sourceTrackTagsMatchPipelineDirection() {
        // AGENTS.md §4: SCK 시스템 오디오 = remote(상대방), AVAudioEngine 마이크 = local(본인).
        let system = SystemAudioCapture()
        #expect(system.track == .remote)
        #expect(MicAudioCapture.trackTag == .local)
        #expect(MicAudioCapture.trackTag != system.track) // 두 트랙 혼동 금지
    }

    @Test func accumulatorTagsChunksWithItsTrack() {
        // 청크 조립 단계에서도 태그가 보존된다 — 어느 소스의 청크든 트랙 필드 출처는 유일.
        var remote = ChunkAccumulator(track: .remote, sampleRate: 48000)
        var local = ChunkAccumulator(track: .local, sampleRate: 48000)
        let remoteChunks = remote.feed(Array(repeating: 0.1, count: 4800), capturedAt: Date())
        let localChunks = local.feed(Array(repeating: 0.1, count: 4800), capturedAt: Date())
        #expect(remoteChunks.allSatisfy { $0.track == .remote })
        #expect(localChunks.allSatisfy { $0.track == .local })
    }
}
