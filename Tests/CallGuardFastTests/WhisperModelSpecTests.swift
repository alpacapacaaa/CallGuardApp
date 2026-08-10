import CryptoKit
import Foundation
@testable import STT
import Testing

struct WhisperModelSpecTests {
    private func writeTempFile(_ bytes: Data) throws -> URL {
        let name = "whisper-model-spec-\(UUID().uuidString)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try bytes.write(to: url)
        return url
    }

    /// DoD(P2-T2): 해시 불일치 시 로드 거부.
    @Test func rejectsHashMismatch() throws {
        let url = try writeTempFile(Data("가짜 모델 바이트".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        let spec = WhisperModelSpec(expectedSHA256: String(repeating: "0", count: 64))
        do {
            try spec.verify(fileAt: url)
            Issue.record("해시 불일치인데 검증을 통과함")
        } catch let error as STTError {
            guard case .modelHashMismatch = error else {
                Issue.record("예상치 못한 STTError: \(error)")
                return
            }
        }
    }

    @Test func acceptsMatchingHash() throws {
        let bytes = Data("정확한 모델 바이트".utf8)
        let url = try writeTempFile(bytes)
        defer { try? FileManager.default.removeItem(at: url) }

        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let spec = WhisperModelSpec(expectedSHA256: digest)
        try spec.verify(fileAt: url) // 던지지 않으면 통과
    }

    @Test func hashComparisonIsCaseInsensitive() throws {
        let bytes = Data("대소문자 무관 확인".utf8)
        let url = try writeTempFile(bytes)
        defer { try? FileManager.default.removeItem(at: url) }

        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let spec = WhisperModelSpec(expectedSHA256: digest.uppercased())
        try spec.verify(fileAt: url)
    }
}
