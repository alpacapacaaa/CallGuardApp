import Foundation

/// 트랙 식별자. 캡처는 소스 단위로 트랙이 결정된다 —
/// SCK 시스템 오디오 = remote(상대방), AVAudioEngine 마이크 = local(본인).
public enum AudioTrack: String, CaseIterable, Sendable, Hashable {
    case remote
    case local

    /// 캡처 세션 산출 파일명 규약 (P1-T4) — 세션 1회가 트랙당 파일 1개를 만든다.
    public var captureFileName: String {
        switch self {
        case .remote: "remote.wav"
        case .local: "local.wav"
        }
    }
}

/// 캡처된 오디오 단위. PCM 모노, -1...1 정규화.
/// 파이프라인 타입 — Sendable 불변 struct (AGENTS.md §5).
public struct AudioChunk: Sendable, Hashable {
    public let track: AudioTrack
    public let samples: [Float]
    public let sampleRate: Int
    /// 캡처(버퍼 완성) 시점. 지연 계측(F-S6)의 시작 타임스탬프.
    public let capturedAt: Date

    public init(track: AudioTrack, samples: [Float], sampleRate: Int, capturedAt: Date) {
        self.track = track
        self.samples = samples
        self.sampleRate = sampleRate
        self.capturedAt = capturedAt
    }

    public var duration: TimeInterval {
        Double(samples.count) / Double(sampleRate)
    }
}

/// 오디오 소스 추상화 (AGENTS.md §4 테스트 주입 지점).
/// SCK·마이크 캡처(P1)와 파일 리플레이(FileAudioSource) 모두 이 프로토콜을 구현한다.
public protocol AudioSource: Sendable {
    var track: AudioTrack { get }
    var sampleRate: Int { get }
    /// 오디오를 실시간으로 방출하는 스트림. 신규 호출은 처음부터 재생산한다.
    /// 단절·실패는 `CaptureError`로 종료 — 조용한 실패 금지(AGENTS.md §5).
    func chunks() -> AsyncThrowingStream<AudioChunk, any Error>
}
