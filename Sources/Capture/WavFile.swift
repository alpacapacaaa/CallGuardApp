import Foundation

/// 최소 WAV(RIFF/WAVE) 파서 — FileAudioSource가 필요한 범위만 (P0-T3).
/// 지원: PCM 16-bit(format 1)·IEEE float 32-bit(format 3). 멀티채널은 모노 다운믹스(채널 평균).
struct WavFile {
    let sampleRate: Int
    let channelCount: Int
    /// 모노 정규화(-1...1) 샘플.
    let samples: [Float]

    private struct Format {
        let code: Int
        let channelCount: Int
        let sampleRate: Int
        let bitsPerSample: Int
    }

    static func parse(_ data: Data) throws -> WavFile {
        guard data.count >= 12 else { throw CaptureError.truncated }
        guard tag(data, 0) == "RIFF", tag(data, 8) == "WAVE" else { throw CaptureError.notWav }

        var format: Format?
        var payload: Data?
        var offset = 12
        while offset + 8 <= data.count {
            let id = tag(data, offset)
            let size = Int(u32(data, offset + 4))
            offset += 8
            guard offset + size <= data.count else { throw CaptureError.truncated }
            switch id {
            case "fmt ": format = try parseFormat(data, offset: offset)
            case "data": payload = slice(data, offset, size)
            default: break
            }
            offset += size + size % 2 // RIFF 청크 패딩
        }

        guard let format else { throw CaptureError.missingFormat }
        guard let payload else { throw CaptureError.missingData }
        return WavFile(
            sampleRate: format.sampleRate,
            channelCount: format.channelCount,
            samples: decode(payload, format: format)
        )
    }

    private static func parseFormat(_ data: Data, offset: Int) throws -> Format {
        guard offset + 16 <= data.count else { throw CaptureError.truncated }
        let format = Format(
            code: Int(u16(data, offset)),
            channelCount: Int(u16(data, offset + 2)),
            sampleRate: Int(u32(data, offset + 4)),
            bitsPerSample: Int(u16(data, offset + 14))
        )
        let supported = (format.code == 1 && format.bitsPerSample == 16)
            || (format.code == 3 && format.bitsPerSample == 32)
        guard supported, format.channelCount >= 1, format.sampleRate > 0 else {
            throw CaptureError.unsupportedFormat(
                detail: "format=\(format.code), bits=\(format.bitsPerSample), channels=\(format.channelCount)"
            )
        }
        return format
    }

    private static func decode(_ payload: Data, format: Format) -> [Float] {
        let bytesPerSample = format.bitsPerSample / 8
        let frameBytes = bytesPerSample * format.channelCount
        let frameCount = payload.count / frameBytes
        var samples = [Float]()
        samples.reserveCapacity(frameCount)
        for frame in 0 ..< frameCount {
            var sum: Float = 0
            for channel in 0 ..< format.channelCount {
                let index = frame * frameBytes + channel * bytesPerSample
                sum += format.bitsPerSample == 16
                    ? Float(Int16(bitPattern: u16(payload, index))) / 32768
                    : Float(bitPattern: u32(payload, index))
            }
            samples.append(sum / Float(format.channelCount))
        }
        return samples
    }

    private static func tag(_ data: Data, _ offset: Int) -> String {
        String(bytes: slice(data, offset, 4), encoding: .utf8) ?? ""
    }

    private static func slice(_ data: Data, _ offset: Int, _ count: Int) -> Data {
        data.subdata(in: data.startIndex + offset ..< data.startIndex + offset + count)
    }

    private static func byte(_ data: Data, _ index: Int) -> UInt8 {
        data[data.startIndex + index]
    }

    private static func u16(_ data: Data, _ index: Int) -> UInt16 {
        UInt16(byte(data, index)) | UInt16(byte(data, index + 1)) << 8
    }

    private static func u32(_ data: Data, _ index: Int) -> UInt32 {
        UInt32(u16(data, index)) | UInt32(u16(data, index + 2)) << 16
    }
}
