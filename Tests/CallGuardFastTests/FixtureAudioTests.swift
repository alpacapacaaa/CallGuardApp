@testable import Capture
import Foundation
import Testing

/// 오디오 픽스처(Tests/Fixtures/audio) 무결성 검증 (P0-T5).
/// 실패 조건: 픽스처 누락·손상·WAV 포맷 훼손 — STT 파이프라인이 소비하기 전에 차단.
struct FixtureAudioTests {
    private static var fixturesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // CallGuardFastTests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Fixtures/audio")
    }

    @Test func fixtureCountMeetsMinimum() throws {
        let count = try Self.wavFiles().count
        #expect(count >= 10, "픽스처 부족: \(count) (P0-T5 최소 10)")
    }

    @Test func allFixturesAreParseableNonEmptyWavs() throws {
        for url in try Self.wavFiles() {
            let file = try WavFile.parse(Data(contentsOf: url))
            #expect(file.samples.count > 0, "빈 오디오: \(url.lastPathComponent)")
            #expect(file.sampleRate > 0, "샘플레이트 이상: \(url.lastPathComponent)")
        }
    }

    @Test func manifestExists() {
        let manifest = Self.fixturesDir.appendingPathComponent("MANIFEST.md").path
        #expect(FileManager.default.fileExists(atPath: manifest), "Tests/Fixtures/audio/MANIFEST.md 누락")
    }

    private static func wavFiles() throws -> [URL] {
        try FileManager.default
            .contentsOfDirectory(at: fixturesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "wav" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
