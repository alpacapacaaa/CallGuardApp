/// 프레임 RMS 에너지 기반 VAD — 외부 DSP 의존성 없이 직접 구현(AGENTS.md §8-5, G10).
enum VoiceActivityDetector {
    /// 정규화(-1...1) 샘플 기준 RMS 임계값. 합성 무음(0)과 톤(≥0.1 진폭) 픽스처를 분리하는 값.
    static let defaultThreshold: Float = 0.02
    /// containsSpeech 슬라이딩 윈도우 크기 — 16kHz 기준 100ms.
    static let defaultWindowFrames = 1600

    static func isSpeech(_ samples: [Float], threshold: Float = defaultThreshold) -> Bool {
        guard !samples.isEmpty else { return false }
        return rms(samples) >= threshold
    }

    /// 세그먼트를 windowFrames 단위로 훑어 하나라도 발화 임계값을 넘으면 true. 실제 통화
    /// 오디오는 문장 사이 무음이 섞여 있어, 최대 8s짜리 청크 전체 평균 RMS(isSpeech)로
    /// 판정하면 발화가 섞인 청크도 평균이 희석돼 무음으로 오판되고 whisper에 아예 안
    /// 들어가 자막이 뜨지 않는 문제가 실통화에서 재현됐다(합성 톤/무음 픽스처는 구간 내
    /// 에너지가 균일해 이 문제가 안 드러남). PreprocessPipeline.makeChunk의 청크 단위
    /// 게이트에는 반드시 이 함수를 써야 한다 — isSpeech는 조기 컷 판단용 짧은(0.5s) 꼬리
    /// 구간 체크 등 이미 좁은 창에 쓰는 용도로 남겨둔다.
    static func containsSpeech(
        _ samples: [Float], windowFrames: Int = defaultWindowFrames, threshold: Float = defaultThreshold
    ) -> Bool {
        guard !samples.isEmpty else { return false }
        var start = 0
        while start < samples.count {
            let end = min(start + windowFrames, samples.count)
            if rms(Array(samples[start ..< end])) >= threshold { return true }
            start = end
        }
        return false
    }

    private static func rms(_ samples: [Float]) -> Float {
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return (sumOfSquares / Float(samples.count)).squareRoot()
    }
}
