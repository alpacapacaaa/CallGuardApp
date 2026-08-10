@testable import Capture
import Foundation
import Testing
import TestSupport

struct WavParsingTests {
    @Test func parsesPcm16Mono() throws {
        let file = try WavFile.parse(WavSynth.pcm16(sampleRate: 16000, channels: 1, duration: 0.05))
        #expect(file.sampleRate == 16000)
        #expect(file.channelCount == 1)
        #expect(file.samples.count == 800)
        // 440Hz 사인: 첫 샘플 0, 두 번째 샘플 양수 — 정규화·엔디언 변환 검증
        #expect(abs(file.samples[0]) < 0.001)
        #expect(file.samples[1] > 0)
    }

    @Test func parsesFloat32() throws {
        let file = try WavFile.parse(WavSynth.float32(sampleRate: 48000, channels: 1, duration: 0.01))
        #expect(file.sampleRate == 48000)
        #expect(file.samples.count == 480)
        #expect(abs(file.samples[0]) < 0.0001)
        #expect(file.samples[1] > 0)
    }

    @Test func downmixesStereoToMono() throws {
        let stereo = try WavFile.parse(WavSynth.pcm16(sampleRate: 8000, channels: 2, duration: 0.02))
        let mono = try WavFile.parse(WavSynth.pcm16(sampleRate: 8000, channels: 1, duration: 0.02))
        #expect(stereo.samples.count == 160)
        #expect(stereo.samples == mono.samples)
    }

    @Test func rejectsNonWavData() {
        #expect(throws: CaptureError.notWav) { try WavFile.parse(Data("RIFF\0\0\0\0AVI ".utf8)) }
        #expect(throws: CaptureError.truncated) { try WavFile.parse(Data([0x52, 0x49])) }
    }

    @Test func rejectsTruncatedChunk() {
        let full = WavSynth.pcm16(sampleRate: 8000, channels: 1, duration: 0.01)
        // fmt 청크 본문 중간에서 절단 — 청크 size가 파일 끝을 넘어감
        #expect(throws: CaptureError.truncated) { try WavFile.parse(full.prefix(30)) }
    }

    @Test func rejectsMissingDataChunk() {
        let full = WavSynth.pcm16(sampleRate: 8000, channels: 1, duration: 0.01)
        // fmt 청크(오프셋 36 종료)까지만 유지하면 data 청크가 없음
        #expect(throws: CaptureError.missingData) { try WavFile.parse(full.prefix(36)) }
    }

    @Test func rejectsMissingFormatChunk() {
        var data = Data("RIFF".utf8)
        data.append(WavSynth.le32(16))
        data.append(Data("WAVE".utf8))
        data.append(Data("data".utf8))
        data.append(WavSynth.le32(4))
        data.append(Data([0, 0, 0, 0]))
        #expect(throws: CaptureError.missingFormat) { try WavFile.parse(data) }
    }

    @Test func rejectsUnsupportedFormats() {
        let payload = Data(repeating: 0, count: 16)
        #expect(throws: CaptureError.self) {
            try WavFile.parse(WavSynth.assemble(
                formatCode: 0x11, bitsPerSample: 16, sampleRate: 8000, channels: 1, payload: payload
            ))
        }
        #expect(throws: CaptureError.self) {
            try WavFile.parse(WavSynth.assemble(
                formatCode: 1, bitsPerSample: 8, sampleRate: 8000, channels: 1, payload: payload
            ))
        }
    }

    @Test func fileSourceRejectsMissingFile() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("callguard-missing-\(UUID()).wav")
        #expect(throws: CaptureError.fileReadFailed(path: missing.path)) {
            try FileAudioSource(url: missing, track: .local)
        }
    }

    @Test func audioTrackCasesAreFixed() {
        #expect(AudioTrack.allCases == [.remote, .local])
    }
}
