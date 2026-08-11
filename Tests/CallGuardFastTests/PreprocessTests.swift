import Capture
import Foundation
@testable import Preprocess
import Testing

struct PreprocessTests {
    @Test func resamples48kTo16kExactRatio() {
        let sourceSamples = (0 ..< 4800).map { Float(sin(2 * Double.pi * 440 * Double($0) / 48000)) }
        let resampled = Resampler.resample(sourceSamples, from: 48000, to: 16000)
        #expect(resampled.count == 1600)
    }

    @Test func resampleIsNoOpWhenRatesMatch() {
        let samples: [Float] = [0.1, 0.2, 0.3]
        #expect(Resampler.resample(samples, from: 16000, to: 16000) == samples)
    }

    @Test func resampleOfEmptyIsEmpty() {
        #expect(Resampler.resample([], from: 48000, to: 16000).isEmpty)
    }

    @Test func vadDetectsSilenceAsNonSpeech() {
        let silence = [Float](repeating: 0, count: 1600)
        #expect(VoiceActivityDetector.isSpeech(silence) == false)
    }

    @Test func vadDetectsToneAsSpeech() {
        let tone = (0 ..< 1600).map { Float(sin(2 * Double.pi * 440 * Double($0) / 16000)) * 0.5 }
        #expect(VoiceActivityDetector.isSpeech(tone))
    }

    @Test func vadOfEmptyIsNonSpeech() {
        #expect(VoiceActivityDetector.isSpeech([]) == false)
    }

    @Test func chunksIntoConfiguredDurationSegmentsWithAccurateTimestamps() {
        // chunkDuration×2.5의 48kHz 합성 톤을 100ms 캡처 청크(FileAudioSource 페이싱과 동일 단위)로 공급.
        var pipeline = PreprocessPipeline(track: .remote)
        let sourceRate = 48000
        let sourceChunkFrames = Int(Double(sourceRate) * 0.1)
        let chunkDuration = PreprocessPipeline.chunkDuration
        let totalFrames = Int(Double(sourceRate) * chunkDuration * 2.5)
        var offset = 0
        var results: [PreprocessedChunk] = []
        while offset < totalFrames {
            let upper = min(offset + sourceChunkFrames, totalFrames)
            let samples = (offset ..< upper).map {
                Float(sin(2 * Double.pi * 440 * Double($0) / Double(sourceRate))) * 0.5
            }
            let chunk = AudioChunk(track: .remote, samples: samples, sampleRate: sourceRate, capturedAt: Date())
            results.append(contentsOf: pipeline.feed(chunk))
            offset = upper
        }
        if let residual = pipeline.flush() {
            results.append(residual)
        }

        // totalDuration(chunkDuration×2.5) = 2개 온전한 청크 + 0.5×chunkDuration 잔여 청크.
        let targetRate = Double(PreprocessPipeline.targetSampleRate)
        #expect(results.count == 3)
        #expect(results[0].samples.count == Int(chunkDuration * targetRate))
        #expect(results[1].samples.count == Int(chunkDuration * targetRate))
        #expect(results[2].samples.count == Int(chunkDuration * 0.5 * targetRate))
        let allAt16k = results.allSatisfy { $0.sampleRate == PreprocessPipeline.targetSampleRate }
        #expect(allAt16k)
        let allSpeech = results.allSatisfy(\.isSpeech)
        #expect(allSpeech)

        let expectedStarts: [TimeInterval] = [0.0, chunkDuration, chunkDuration * 2]
        for (result, expected) in zip(results, expectedStarts) {
            // DoD: 청크 경계 오차 ≤ 50ms.
            #expect(abs(result.startTime - expected) <= 0.05)
        }
    }

    @Test func flushReturnsNilWhenNoResidual() {
        var pipeline = PreprocessPipeline(track: .local)
        let exactChunkFrames = Int(PreprocessPipeline.chunkDuration * Double(PreprocessPipeline.targetSampleRate))
        let chunk = AudioChunk(
            track: .local,
            samples: [Float](repeating: 0, count: exactChunkFrames),
            sampleRate: PreprocessPipeline.targetSampleRate,
            capturedAt: Date()
        )
        let results = pipeline.feed(chunk)
        #expect(results.count == 1)
        #expect(pipeline.flush() == nil)
    }
}
