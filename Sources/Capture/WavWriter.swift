import Foundation

/// PCM 16-bit 모노 WAV(RIFF/WAVE) 라이터 — 캡처 산출물 저장(P1-T2), WavFile과 대칭.
/// 헤더의 RIFF·data 크기는 close() 시점에 확정된다 — append 중에는 자리표시자(0).
/// 정규화(-1...1) float 샘플을 Int16으로 양자화하며 범위를 벗어난 값은 클립한다.
public final class WavWriter {
    public static let headerSize = 44

    public let url: URL
    public let sampleRate: Int
    public private(set) var framesWritten = 0
    private let handle: FileHandle
    private var closed = false

    public init(url: URL, sampleRate: Int) throws {
        self.url = url
        self.sampleRate = sampleRate
        let header = Self.header(sampleRate: sampleRate, dataByteCount: 0)
        do {
            try header.write(to: url)
            handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd() // FileHandle 기본 오프셋은 0 — 헤더 이후부터 기록해야 한다
        } catch {
            throw CaptureError.wavWriteFailed(path: url.path)
        }
    }

    deinit {
        // close() 누락 시에도 열린 FileHandle을 남기지 않는다 — 미확정 헤더 파일은 재생 불가가 정상.
        try? handle.close()
    }

    public func append(_ samples: [Float]) throws {
        guard !closed else { throw CaptureError.wavWriteFailed(path: url.path) }
        guard !samples.isEmpty else { return }
        var payload = Data(capacity: samples.count * 2)
        for sample in samples {
            let clipped = min(max(sample, -1), 1)
            let quantized = Int16(clipped >= 0 ? clipped * 32767 : clipped * 32768)
            payload.append(contentsOf: withUnsafeBytes(of: quantized.littleEndian) { Array($0) })
        }
        do {
            try handle.write(contentsOf: payload)
        } catch {
            throw CaptureError.wavWriteFailed(path: url.path)
        }
        framesWritten += samples.count
    }

    /// 헤더 크기를 확정하고 파일을 닫는다 — 이 시점 이후 파일이 재생 가능해진다.
    public func close() throws {
        guard !closed else { return }
        do {
            try handle.seek(toOffset: 0)
            try handle.write(contentsOf: Self.header(sampleRate: sampleRate, dataByteCount: framesWritten * 2))
            try handle.close()
        } catch {
            throw CaptureError.wavWriteFailed(path: url.path)
        }
        closed = true
    }

    /// 44바이트 표준 헤더 — WavSynth.assemble과 동일한 레이아웃(fmt 16B + data).
    static func header(sampleRate: Int, dataByteCount: Int) -> Data {
        var data = Data(capacity: headerSize)
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(le32(UInt32(36 + dataByteCount)))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.append(le32(16))
        data.append(le16(1)) // PCM
        data.append(le16(1)) // 모노 — 파이프라인 모노 계약(AudioChunk)
        data.append(le32(UInt32(sampleRate)))
        data.append(le32(UInt32(sampleRate * 2))) // 바이트레이트 = sampleRate * channels * bits/8
        data.append(le16(2)) // 프레임 바이트 = channels * bits/8
        data.append(le16(16))
        data.append(contentsOf: Array("data".utf8))
        data.append(le32(UInt32(dataByteCount)))
        return data
    }

    private static func le16(_ value: UInt16) -> Data {
        var littleEndian = value.littleEndian
        return Data(bytes: &littleEndian, count: 2)
    }

    private static func le32(_ value: UInt32) -> Data {
        var littleEndian = value.littleEndian
        return Data(bytes: &littleEndian, count: 4)
    }
}
