@testable import Detection
import Foundation
import Testing

/// 실제 저장소 rules.yaml/rules.yaml.sig를 로드해 검증 — 별도 픽스처와의 드리프트를 없앤다.
/// scripts/check_rule_coverage.sh가 여기 등장하는 룰 ID 문자열을 grep해 커버리지를 검사하므로
/// 룰 ID 리터럴은 rules.yaml과 정확히 일치해야 한다.
struct RuleEngineTests {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // RuleEngineTests.swift
        .deletingLastPathComponent() // CallGuardFastTests
        .deletingLastPathComponent() // Tests

    private func makeEngine() throws -> RuleEngine {
        let rulesURL = Self.repoRoot.appendingPathComponent("rules.yaml")
        let sigURL = Self.repoRoot.appendingPathComponent("rules.yaml.sig")
        let data = try Data(contentsOf: rulesURL)
        let signature = try String(contentsOf: sigURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return try RuleEngine.load(rulesData: data, expectedSignature: signature)
    }

    @Test func loadsAllFiveCategories() throws {
        let engine = try makeEngine()
        #expect(Set(engine.rules.map(\.category)) == Set(RiskCategory.allCases))
    }

    @Test func rejectsSignatureMismatch() throws {
        let rulesURL = Self.repoRoot.appendingPathComponent("rules.yaml")
        let data = try Data(contentsOf: rulesURL)
        let wrongSignature = String(repeating: "0", count: 64)
        #expect(throws: RuleEngineError.signatureMismatch) {
            try RuleEngine.load(rulesData: data, expectedSignature: wrongSignature)
        }
    }

    /// "impersonation-authority" — 기관사칭
    @Test func impersonationAuthorityPositive() throws {
        let matches = try makeEngine().evaluate(text: "여기는 검찰청 수사관입니다, 사건에 연루되셨습니다")
        #expect(matches.contains { $0.ruleID == "impersonation-authority" })
    }

    @Test func impersonationAuthorityNegative() throws {
        let matches = try makeEngine().evaluate(text: "안녕하세요 은행 상담 도와드릴게요")
        #expect(!matches.contains { $0.ruleID == "impersonation-authority" })
    }

    /// "account-transfer" — 계좌송금
    @Test func accountTransferPositive() throws {
        let matches = try makeEngine().evaluate(text: "안전계좌로 지금 이체하셔야 합니다")
        #expect(matches.contains { $0.ruleID == "account-transfer" })
    }

    @Test func accountTransferNegative() throws {
        let matches = try makeEngine().evaluate(text: "오늘 날씨가 참 좋네요")
        #expect(!matches.contains { $0.ruleID == "account-transfer" })
    }

    /// "app-install-lure" — 앱설치유도
    @Test func appInstallLurePositive() throws {
        let matches = try makeEngine().evaluate(text: "이 앱을 설치하고 원격 제어를 허용해주세요")
        #expect(matches.contains { $0.ruleID == "app-install-lure" })
    }

    @Test func appInstallLureNegative() throws {
        let matches = try makeEngine().evaluate(text: "택배가 내일 도착합니다")
        #expect(!matches.contains { $0.ruleID == "app-install-lure" })
    }

    /// "personal-info-demand" — 개인정보요구
    @Test func personalInfoDemandPositive() throws {
        let matches = try makeEngine().evaluate(text: "주민등록번호를 불러주시고 보안카드 번호도 알려주세요")
        #expect(matches.contains { $0.ruleID == "personal-info-demand" })
    }

    @Test func personalInfoDemandNegative() throws {
        let matches = try makeEngine().evaluate(text: "회의는 오후 3시에 시작합니다")
        #expect(!matches.contains { $0.ruleID == "personal-info-demand" })
    }

    /// "threat-urgency" — 협박긴급성
    @Test func threatUrgencyPositive() throws {
        let matches = try makeEngine().evaluate(text: "지금 당장 응하지 않으면 즉시 체포됩니다")
        #expect(matches.contains { $0.ruleID == "threat-urgency" })
    }

    @Test func threatUrgencyNegative() throws {
        let matches = try makeEngine().evaluate(text: "천천히 생각해보고 다시 연락드릴게요")
        #expect(!matches.contains { $0.ruleID == "threat-urgency" })
    }
}
