import AlertPolicy
import AppKit
import CallGuardUI
import Detection
import Foundation
import STT
import SwiftUI

enum RenderError: Error { case failed(String) }

@MainActor
func renderPNG(view: some View, to path: String) throws {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0
    guard let nsImage = renderer.nsImage,
          let tiffData = nsImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw RenderError.failed(path)
    }
    try pngData.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

let outputDir = "docs/ui"
try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

let evidence = [
    TranscriptSegment(track: .remote, text: "지금 즉시 계좌를 확인해야 합니다", startTime: 0, endTime: 2, isFinal: true),
    TranscriptSegment(track: .remote, text: "체포영장이 발부되었습니다", startTime: 2, endTime: 4, isFinal: true),
]

let noneVM = AlertViewModel(level: .none, score: nil)
let cautionScore = RiskScore(value: 0.6, category: .institutionImpersonation, evidence: evidence)
let cautionVM = AlertViewModel(level: .caution, score: cautionScore)
let dangerScore = RiskScore(value: 0.9, category: .threatUrgency, evidence: evidence)
let dangerVM = AlertViewModel(level: .danger, score: dangerScore)

try await renderPNG(view: MenuBarStateView(viewModel: noneVM), to: "\(outputDir)/menubar-none.png")
try await renderPNG(view: CautionBannerView(viewModel: cautionVM), to: "\(outputDir)/caution-banner.png")
try await renderPNG(view: DangerPanelView(viewModel: dangerVM), to: "\(outputDir)/danger-panel.png")
