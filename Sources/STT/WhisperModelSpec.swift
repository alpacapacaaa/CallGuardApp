import CryptoKit
import Foundation

/// whisper.cpp 모델 파일 무결성 검증(P2-T2, AGENTS.md §4 "모델 파일 SHA256 고정").
/// 앤트로픽 앱은 모델 파일을 저장소에 커밋하지 않는다(G5·용량) — 배포/캐시 경로에서
/// 내려받은 파일의 해시가 이 스펙과 다르면 whisper_init 자체를 호출하지 않는다.
public struct WhisperModelSpec: Sendable, Hashable {
    public let expectedSHA256: String

    public init(expectedSHA256: String) {
        self.expectedSHA256 = expectedSHA256.lowercased()
    }

    public func verify(fileAt url: URL) throws {
        let data = try Data(contentsOf: url)
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual == expectedSHA256 else {
            throw STTError.modelHashMismatch(expected: expectedSHA256, actual: actual)
        }
    }
}
