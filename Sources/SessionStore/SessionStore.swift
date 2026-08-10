import CryptoKit
import Foundation
import GRDB

/// 세션 저장 모듈. 기본 폐기(F-M7) — 이 타입의 메서드를 호출하지 않으면 아무것도 디스크에
/// 남지 않는다. 옵트인 시에만 save()가 호출되며, 그 경우에도 전사 필드는 CryptoKit
/// AES-GCM으로 암호화한 뒤 GRDB(SQLite)에 저장한다(AGENTS.md §4 "GRDB + 필드 암호화").
/// journal_mode=DELETE로 고정 — WAL 파일에 평문이 잠시라도 남는 경로를 없앤다.
public struct SessionStore: Sendable {
    private let dbQueue: DatabaseQueue
    private let key: SymmetricKey

    public init(path: String, key: SymmetricKey) throws {
        var configuration = Configuration()
        configuration.prepareDatabase { database in
            try database.execute(sql: "PRAGMA journal_mode = DELETE")
        }
        dbQueue = try DatabaseQueue(path: path, configuration: configuration)
        self.key = key
        try dbQueue.write { database in
            try database.execute(sql: """
            CREATE TABLE IF NOT EXISTS session_record (
                id TEXT PRIMARY KEY,
                createdAt DATETIME NOT NULL,
                encryptedTranscript BLOB NOT NULL
            )
            """)
        }
    }

    /// 옵트인 세션을 저장한다. transcript는 이 함수 안에서만 평문으로 존재하고,
    /// SQL 바인딩 전에 암호화된 Data로 치환된다 — G1: 평문이 SQL 문자열에 등장하지 않는다.
    public func save(_ record: OptInSessionRecord) throws {
        let sealed = try AES.GCM.seal(Data(record.transcript.utf8), using: key)
        guard let combined = sealed.combined else { throw SessionStoreError.encryptionFailed }
        try dbQueue.write { database in
            try database.execute(
                sql: "INSERT OR REPLACE INTO session_record (id, createdAt, encryptedTranscript) VALUES (?, ?, ?)",
                arguments: [record.id, record.createdAt, combined]
            )
        }
    }

    public func fetch(id: String) throws -> OptInSessionRecord? {
        try dbQueue.read { database in
            guard let row = try Row.fetchOne(
                database,
                sql: "SELECT id, createdAt, encryptedTranscript FROM session_record WHERE id = ?",
                arguments: [id]
            ) else {
                return nil
            }
            let encrypted: Data = row["encryptedTranscript"]
            let sealedBox = try AES.GCM.SealedBox(combined: encrypted)
            guard let plaintext = try? AES.GCM.open(sealedBox, using: key),
                  let transcript = String(bytes: plaintext, encoding: .utf8)
            else {
                throw SessionStoreError.decryptionFailed
            }
            return OptInSessionRecord(id: row["id"], createdAt: row["createdAt"], transcript: transcript)
        }
    }
}
