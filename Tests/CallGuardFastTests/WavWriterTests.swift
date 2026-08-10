@testable import Capture
import Foundation
import Testing

/// P1-T2 자동 판정: 캡처 산출 WAV의 헤더·샘플레이트·라운드트립 검증.
struct WavWriterTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("callguard-wavwriter-\(UUID()).wav")
    }

    @Test func writesValidPcm16MonoHeader() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try WavWriter(url: url, sampleRate: 48000)
        try writer.append([0, 0.5, -0.5])
        try writer.close()

        let data = try Data(contentsOf: url)
        #expect(data.count == WavWriter.headerSize + 6)
        #expect(Self.tag(data, 0) == "RIFF")
        #expect(Self.tag(data, 8) == "WAVE")
        #expect(Self.u16(data, 20) == 1) // PCM 포맷 코드
        #expect(Self.u16(data, 22) == 1) // 모노
        #expect(Self.u32(data, 24) == 48000) // 샘플레이트
        #expect(Self.u32(data, 28) == 96000) // 바이트레이트 = 48000 × 1ch × 2B
        #expect(Self.u16(data, 32) == 2) // 프레임 바이트
        #expect(Self.u16(data, 34) == 16) // 비트 깊이
        #expect(Self.u32(data, 40) == 6) // data 바이트 = 3프레임 × 2B
        #expect(Self.u32(data, 4) == 42) // RIFF 크기 = 36 + data
    }

    @Test func roundTripsThroughWavFile() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let frames = 2400 // 48kHz × 0.05s
        let original = (0 ..< frames).map { Float(sin(2 * Double.pi * 440 * Double($0) / 48000)) * 0.5 }

        let writer = try WavWriter(url: url, sampleRate: 48000)
        try writer.append(original)
        try writer.close()

        let parsed = try WavFile.parse(Data(contentsOf: url))
        #expect(parsed.sampleRate == 48000)
        #expect(parsed.channelCount == 1)
        #expect(parsed.samples.count == frames)
        let maxDeviation = zip(parsed.samples, original).reduce(Float(0)) { max($0, abs($1.0 - $1.1)) }
        #expect(maxDeviation < 0.0001) // Int16 양자화 오차 상한
    }

    @Test func clipsOutOfRangeSamples() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try WavWriter(url: url, sampleRate: 48000)
        try writer.append([1.5, -1.5, 0])
        try writer.close()

        let parsed = try WavFile.parse(Data(contentsOf: url))
        #expect(parsed.samples[0] > 0.999) // +클립 → Int16.max
        #expect(parsed.samples[1] < -0.999) // -클립 → Int16.min
        #expect(parsed.samples[2] == 0)
    }

    @Test func accumulatesAcrossAppends() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try WavWriter(url: url, sampleRate: 48000)
        try writer.append(Array(repeating: 0.1, count: 100))
        try writer.append(Array(repeating: -0.1, count: 200))
        try writer.append(Array(repeating: 0, count: 180))
        #expect(writer.framesWritten == 480)
        try writer.close()

        let parsed = try WavFile.parse(Data(contentsOf: url))
        #expect(parsed.samples.count == 480)
        #expect(try Self.u32(Data(contentsOf: url), 40) == 960)
    }

    @Test func appendAfterCloseFails() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try WavWriter(url: url, sampleRate: 48000)
        try writer.close()
        #expect(throws: CaptureError.wavWriteFailed(path: url.path)) { try writer.append([0.1]) }
        // close 중복은 무해해야 한다(멱등).
        try writer.close()
    }

    @Test func rejectsMissingDirectory() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("callguard-missing-dir-\(UUID())/out.wav")
        #expect(throws: CaptureError.wavWriteFailed(path: url.path)) {
            try WavWriter(url: url, sampleRate: 48000)
        }
    }

    private static func tag(_ data: Data, _ offset: Int) -> String {
        let range = data.startIndex + offset ..< data.startIndex + offset + 4
        return String(bytes: data.subdata(in: range), encoding: .utf8) ?? ""
    }

    private static func u16(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[data.startIndex + offset]) | UInt16(data[data.startIndex + offset + 1]) << 8
    }

    private static func u32(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(u16(data, offset)) | UInt32(u16(data, offset + 2)) << 16
    }
}
