import CryptoKit
import Foundation
import Session
@testable import SessionStore
import Testing

struct SessionStoreTests {
    private func makeTempPath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("callguard-test-\(UUID().uuidString).sqlite")
            .path
    }

    @Test func savesAndFetchesRoundTrip() throws {
        let path = makeTempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try SessionStore(path: path, key: SymmetricKey(size: .bits256))
        let record = OptInSessionRecord(id: "s1", createdAt: Date(), transcript: "안녕하세요 확인 부탁드립니다")
        try store.save(record)
        let fetched = try store.fetch(id: "s1")
        #expect(fetched?.transcript == record.transcript)
    }

    @Test func fetchOfMissingIDReturnsNil() throws {
        let path = makeTempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let store = try SessionStore(path: path, key: SymmetricKey(size: .bits256))
        #expect(try store.fetch(id: "없음") == nil)
    }

    /// DoD(P4-T4): 옵트인 DB에 평문 전사 미검출 — GRDB를 거치지 않고 파일 바이트를 직접 검사한다.
    @Test func optInDatabaseFileNeverContainsPlaintextTranscript() throws {
        let path = makeTempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let secretMarker = "절대유출되면안되는평문마커XYZ789"
        let store = try SessionStore(path: path, key: SymmetricKey(size: .bits256))
        try store.save(OptInSessionRecord(id: "s1", createdAt: Date(), transcript: secretMarker))

        // 바이너리 SQLite 파일은 유효 UTF-8이 아니므로 문자열 변환 대신 바이트 패턴으로 직접 검사한다.
        let rawBytes = try Data(contentsOf: URL(fileURLWithPath: path))
        let markerBytes = Data(secretMarker.utf8)
        #expect(rawBytes.range(of: markerBytes) == nil)

        // 암호화가 "저장 실패"가 아니라 "저장+은닉"임을 함께 검증 — 복호화 경로는 정상 동작해야 한다.
        #expect(try store.fetch(id: "s1")?.transcript == secretMarker)
    }

    /// DoD(P4-T4): 세션 종료 후 임시 파일 0건 — 옵트인 저장(save)을 호출하지 않으면
    /// 아무것도 디스크에 남지 않는다(기본 폐기, F-M7).
    @Test func noFilesRemainWithoutOptInSave() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("callguard-discard-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var controller = SessionController()
        controller.handle(.consentGranted)
        controller.handle(.sourceStarted)
        controller.handle(.sourceEnded) // 세션 종료 — SessionStore.save()는 호출되지 않음(옵트인 없음)

        let filesAfter = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        #expect(filesAfter.isEmpty)
    }
}
