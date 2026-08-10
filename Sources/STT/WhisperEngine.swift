import Foundation
import whisper

/// whisper.cpp 단발 추론 래퍼(P2-T2). 트랙별 스트리밍 인스턴스화는 P2-T3 범위 —
/// 이 타입은 PCM 버퍼 1개를 한 번에 전사하는 최소 계약만 제공한다.
/// whisper_context는 동시에 여러 스레드에서 쓰면 안전하지 않다(whisper.h 상단 주석) —
/// 이 타입은 Sendable을 선언하지 않는다. 동시성 경계는 P2-T3에서 실제 스트리밍 요구에
/// 맞춰 설계한다(AGENTS.md §8-5: 필요 이상으로 미리 설계하지 않는다).
public final class WhisperEngine {
    private let context: OpaquePointer

    /// modelURL의 해시를 spec으로 검증한 뒤에만 whisper_init을 호출한다 — 검증 전 로드 금지.
    public init(modelURL: URL, spec: WhisperModelSpec) throws {
        try spec.verify(fileAt: modelURL)

        var contextParams = whisper_context_default_params()
        contextParams.use_gpu = true // Metal(AGENTS.md §4 "STT: whisper.cpp (Metal, ...)")

        guard let context = modelURL.path.withCString({ path in
            whisper_init_from_file_with_params(path, contextParams)
        }) else {
            throw STTError.modelLoadFailed(path: modelURL.path)
        }
        self.context = context
    }

    deinit {
        whisper_free(context)
    }

    /// samples: 16kHz 모노 PCM(-1...1) — Preprocess 파이프라인 출력 샘플레이트와 동일.
    /// 반환: 전체 세그먼트를 이어붙인 텍스트(공백 트리밍).
    public func transcribe(samples: [Float], language: String = "ko") throws -> String {
        var fullParams = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        fullParams.print_progress = false
        fullParams.print_realtime = false
        fullParams.print_special = false

        let result: Int32 = language.withCString { languagePointer in
            fullParams.language = languagePointer
            return samples.withUnsafeBufferPointer { buffer in
                whisper_full(context, fullParams, buffer.baseAddress, Int32(buffer.count))
            }
        }
        guard result == 0 else { throw STTError.transcriptionFailed }

        let segmentCount = whisper_full_n_segments(context)
        var text = ""
        for index in 0 ..< segmentCount {
            if let segment = whisper_full_get_segment_text(context, index) {
                text += String(cString: segment)
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
