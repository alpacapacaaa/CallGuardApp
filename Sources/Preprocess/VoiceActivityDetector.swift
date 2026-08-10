/// 프레임 RMS 에너지 기반 VAD — 외부 DSP 의존성 없이 직접 구현(AGENTS.md §8-5, G10).
enum VoiceActivityDetector {
    /// 정규화(-1...1) 샘플 기준 RMS 임계값. 합성 무음(0)과 톤(≥0.1 진폭) 픽스처를 분리하는 값.
    static let defaultThreshold: Float = 0.02

    static func isSpeech(_ samples: [Float], threshold: Float = defaultThreshold) -> Bool {
        guard !samples.isEmpty else { return false }
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        let rms = (sumOfSquares / Float(samples.count)).squareRoot()
        return rms >= threshold
    }
}
