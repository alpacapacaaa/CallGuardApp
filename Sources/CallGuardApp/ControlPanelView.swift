import AlertPolicy
import CallGuardUI
import SwiftUI
import UniformTypeIdentifiers

struct ControlPanelView: View {
    let appState: AppState
    @State private var isImporterPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CallGuard").font(.headline)

            if !appState.hasConsent {
                Text("상대방 음성을 처리·분석하는 데 동의가 필요합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("동의하고 시작") { appState.grantConsent() }
            } else {
                Button(appState.isPlaying ? "재생 중..." : "통화 녹음 파일 선택") {
                    isImporterPresented = true
                }
                .disabled(appState.isPlaying)
                .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.audio]) { result in
                    if case let .success(url) = result {
                        appState.start(fileURL: url)
                    }
                }

                Button(appState.isPlaying ? "재생 중..." : "실시간 통화 캡처 시작") {
                    appState.startLiveCapture()
                }
                .disabled(appState.isPlaying)

                if appState.isPlaying {
                    Button("중지", role: .destructive) { appState.stopPlayback() }
                }
            }

            Divider()

            Text(appState.statusMessage).font(.caption)

            if appState.alertLevel == .caution {
                CautionBannerView(viewModel: AlertViewModel(level: .caution, score: appState.currentScore))
            }

            if !appState.transcriptLog.isEmpty {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(appState.transcriptLog) { entry in
                            Text("[\(entry.timestamp)] \(entry.text)")
                                .font(.caption2)
                                .foregroundStyle(entry.level == .none ? .secondary : .primary)
                        }
                    }
                }
                .frame(maxHeight: 160)
            }
        }
        .padding()
        .frame(width: 340)
    }
}
