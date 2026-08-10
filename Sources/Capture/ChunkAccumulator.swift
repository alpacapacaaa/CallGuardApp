import Foundation

/// 임의 크기로 도착하는 캡처 샘플을 FileAudioSource와 동일한 청크 계약(기본 100ms)으로
/// 재조립한다. SCK·마이크 등 실제 장치는 버퍼 크기를 보장하지 않으므로 파이프라인 진입
/// 직전에 청크 단위를 통일한다 — 지연 계측(F-S6)의 타임스탬프 비교 가능성을 유지.
struct ChunkAccumulator {
    let track: AudioTrack
    let sampleRate: Int
    let chunkFrames: Int
    private(set) var pending: [Float] = []

    init(track: AudioTrack, sampleRate: Int, chunkDuration: TimeInterval = FileAudioSource.chunkDuration) {
        self.track = track
        self.sampleRate = sampleRate
        chunkFrames = max(1, Int((Double(sampleRate) * chunkDuration).rounded()))
    }

    /// 샘플을 누적하고 완성된 100ms 청크들을 방출 순서대로 반환한다.
    /// capturedAt은 버퍼 완성 시점 — FileAudioSource의 방출 시점 의미와 동일.
    mutating func feed(_ samples: [Float], capturedAt: Date) -> [AudioChunk] {
        guard !samples.isEmpty else { return [] }
        pending.append(contentsOf: samples)
        var chunks: [AudioChunk] = []
        while pending.count >= chunkFrames {
            chunks.append(AudioChunk(
                track: track,
                samples: Array(pending[..<chunkFrames]),
                sampleRate: sampleRate,
                capturedAt: capturedAt
            ))
            pending.removeFirst(chunkFrames)
        }
        return chunks
    }

    /// 스트림 종료 시 잔여 샘플을 마지막(짧은) 청크로 방출한다 — 잔여분이 없으면 nil.
    mutating func flush(capturedAt: Date) -> AudioChunk? {
        guard !pending.isEmpty else { return nil }
        let chunk = AudioChunk(
            track: track,
            samples: pending,
            sampleRate: sampleRate,
            capturedAt: capturedAt
        )
        pending.removeAll()
        return chunk
    }
}
