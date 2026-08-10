@testable import AlertPolicy
@testable import CallGuardUI
import Detection
import STT
import Testing

struct AlertViewModelTests {
    @Test func noneLevelHasNoScoreDetails() {
        let viewModel = AlertViewModel(level: .none, score: nil)
        #expect(viewModel.categoryLabel == nil)
        #expect(viewModel.evidenceLines.isEmpty)
        #expect(viewModel.recommendedAction == nil)
    }

    @Test func dangerLevelIncludesCategoryEvidenceAndAction() {
        let evidence = [
            TranscriptSegment(track: .remote, text: "즉시 체포됩니다", startTime: 0, endTime: 2, isFinal: true),
            TranscriptSegment(track: .remote, text: "지금 당장 응하세요", startTime: 2, endTime: 4, isFinal: true),
        ]
        let score = RiskScore(value: 0.9, category: .threatUrgency, evidence: evidence)
        let viewModel = AlertViewModel(level: .danger, score: score)

        #expect(viewModel.categoryLabel == "협박·긴급성")
        #expect(viewModel.evidenceLines.count == 2)
        #expect(viewModel.recommendedAction != nil)
    }

    @Test func evidenceCappedAtThree() {
        let evidence = (0 ..< 5).map {
            TranscriptSegment(
                track: .remote, text: "발화\($0)", startTime: Double($0), endTime: Double($0) + 1, isFinal: true
            )
        }
        let score = RiskScore(value: 0.9, category: .accountTransfer, evidence: evidence)
        let viewModel = AlertViewModel(level: .danger, score: score)
        #expect(viewModel.evidenceLines.count == 3)
    }

    @Test func cautionLevelHasNoRecommendedAction() {
        let score = RiskScore(value: 0.6, category: .accountTransfer, evidence: [])
        let viewModel = AlertViewModel(level: .caution, score: score)
        #expect(viewModel.recommendedAction == nil)
    }
}
