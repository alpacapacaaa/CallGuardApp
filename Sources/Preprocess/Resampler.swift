/// 선형 보간 리샘플러 — 외부 DSP 의존성 없이 직접 구현(AGENTS.md §8-5, G10).
enum Resampler {
    /// `sourceRate`에서 `targetRate`로 선형 보간 리샘플링한다.
    /// 정수배 비율(예: 48000→16000)에서는 보간 지점이 항상 정수 인덱스에 맞아떨어져
    /// 오차 없는 데시메이션과 동일하게 동작한다.
    static func resample(_ samples: [Float], from sourceRate: Int, to targetRate: Int) -> [Float] {
        guard !samples.isEmpty, sourceRate != targetRate else { return samples }
        let ratio = Double(sourceRate) / Double(targetRate)
        let outputCount = Int((Double(samples.count) / ratio).rounded())
        guard outputCount > 0 else { return [] }
        var output = [Float]()
        output.reserveCapacity(outputCount)
        for index in 0 ..< outputCount {
            let sourcePosition = Double(index) * ratio
            let sourceIndex = Int(sourcePosition)
            guard sourceIndex < samples.count else { break }
            if sourceIndex + 1 < samples.count {
                let fraction = Float(sourcePosition - Double(sourceIndex))
                let low = samples[sourceIndex]
                let high = samples[sourceIndex + 1]
                output.append(low + (high - low) * fraction)
            } else {
                output.append(samples[sourceIndex])
            }
        }
        return output
    }
}
