import CryptoKit
import Foundation

/// rules.yaml 무결성 검증(F-S5) — SHA256 다이제스트 비교.
/// CryptoKit은 Apple 시스템 프레임워크 — Package.swift 의존성 추가 없이 사용 가능(G10 비대상).
enum RuleSignature {
    static func hexDigest(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
