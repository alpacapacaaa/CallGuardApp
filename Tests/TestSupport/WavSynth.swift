import Foundation

/// 테스트용 합성 WAV 생성기. 커밋되는 픽스처는 합성 데이터만 허용(AGENTS.md G5).
public enum WavSynth {
    /// 440Hz 사인파 PCM 16-bit WAV 바이트.
    public static func pcm16(
        sampleRate: Int,
        channels: Int,
        duration: TimeInterval,
        amplitude: Double = 0.25
    ) -> Data {
        let frameCount = Int((Double(sampleRate) * duration).rounded())
        var payload = Data(capacity: frameCount * channels * 2)
        for frame in 0 ..< frameCount {
            let value = Int16(sin(2 * Double.pi * 440 * Double(frame) / Double(sampleRate)) * amplitude * 32767)
            appendLittleEndian(value, to: &payload, repeat: channels)
        }
        return assemble(formatCode: 1, bitsPerSample: 16, sampleRate: sampleRate, channels: channels, payload: payload)
    }

    /// 440Hz 사인파 IEEE float 32-bit WAV 바이트.
    public static func float32(
        sampleRate: Int,
        channels: Int,
        duration: TimeInterval,
        amplitude: Double = 0.25
    ) -> Data {
        let frameCount = Int((Double(sampleRate) * duration).rounded())
        var payload = Data(capacity: frameCount * channels * 4)
        for frame in 0 ..< frameCount {
            let value = Float(sin(2 * Double.pi * 440 * Double(frame) / Double(sampleRate)) * amplitude)
            appendLittleEndian(value, to: &payload, repeat: channels)
        }
        return assemble(formatCode: 3, bitsPerSample: 32, sampleRate: sampleRate, channels: channels, payload: payload)
    }

    /// 임의 포맷 조합의 WAV 조립 — 미지원 포맷 거부 테스트는 지원하지 않는 조합을 전달한다.
    public static func assemble(
        formatCode: Int,
        bitsPerSample: Int,
        sampleRate: Int,
        channels: Int,
        payload: Data
    ) -> Data {
        var data = Data(capacity: 44 + payload.count)
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(le32(UInt32(36 + payload.count)))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.append(le32(16))
        data.append(le16(UInt16(formatCode)))
        data.append(le16(UInt16(channels)))
        data.append(le32(UInt32(sampleRate)))
        data.append(le32(UInt32(sampleRate * channels * bitsPerSample / 8)))
        data.append(le16(UInt16(channels * bitsPerSample / 8)))
        data.append(le16(UInt16(bitsPerSample)))
        data.append(contentsOf: Array("data".utf8))
        data.append(le32(UInt32(payload.count)))
        data.append(payload)
        return data
    }

    public static func le16(_ value: UInt16) -> Data {
        var littleEndian = value.littleEndian
        return Data(bytes: &littleEndian, count: 2)
    }

    public static func le32(_ value: UInt32) -> Data {
        var littleEndian = value.littleEndian
        return Data(bytes: &littleEndian, count: 4)
    }

    private static func appendLittleEndian(_ value: Int16, to data: inout Data, repeat count: Int) {
        let bytes = le16(UInt16(bitPattern: value))
        for _ in 0 ..< count {
            data.append(bytes)
        }
    }

    private static func appendLittleEndian(_ value: Float, to data: inout Data, repeat count: Int) {
        let bytes = le32(value.bitPattern)
        for _ in 0 ..< count {
            data.append(bytes)
        }
    }
}
