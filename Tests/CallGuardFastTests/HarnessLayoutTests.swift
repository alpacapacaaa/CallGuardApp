import Foundation
import Testing

/// 하네스 필수 파일 배치 검증 (AGENTS.md §1·§2, P0-T2).
/// 실패 조건: 필수 문서 누락, scripts/ci_fast.sh 부재·실행 비트 상실 → DoD 수행 불가.
struct HarnessLayoutTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // CallGuardFastTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // 저장소 루트
    }

    @Test func harnessDocumentsExist() {
        for document in ["AGENTS.md", "STATE.md", "plan.md", "PRD.md"] {
            let path = Self.repoRoot.appendingPathComponent(document).path
            #expect(
                FileManager.default.fileExists(atPath: path),
                "필수 하네스 문서 누락: \(document)"
            )
        }
    }

    @Test func ciFastScriptIsExecutable() {
        let path = Self.repoRoot.appendingPathComponent("scripts/ci_fast.sh").path
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        #expect(exists && !isDirectory.boolValue, "scripts/ci_fast.sh 누락")
        #expect(FileManager.default.isExecutableFile(atPath: path), "scripts/ci_fast.sh 실행 비트 없음")
    }
}
