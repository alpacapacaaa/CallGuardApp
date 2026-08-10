import Foundation

/// 옵트인 저장 레코드(F-M7). 사용자가 명시적으로 저장에 동의한 세션만 이 타입으로 넘어온다 —
/// 동의 없는 세션은 SessionStore에 절대 전달되지 않는다(호출부 책임, G7).
public struct OptInSessionRecord: Sendable, Hashable {
    public let id: String
    public let createdAt: Date
    /// 평문 전사 — SessionStore.save()가 저장 직전 암호화한다. 이 타입 자체는 메모리에서만 존재.
    public let transcript: String

    public init(id: String, createdAt: Date, transcript: String) {
        self.id = id
        self.createdAt = createdAt
        self.transcript = transcript
    }
}
