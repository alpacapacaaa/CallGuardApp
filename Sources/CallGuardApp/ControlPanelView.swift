import AlertPolicy
import CallGuardUI
import Capture
import SwiftUI
import UniformTypeIdentifiers

struct ControlPanelView: View {
    let appState: AppState
    @State private var isImporterPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CallGuard").font(.headline)
                Spacer()
                CaptureStatusChip(isPlaying: appState.isPlaying, startTime: appState.captureStartTime)
            }

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
                transcriptView
            }
        }
        .padding()
        .frame(width: 340)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(appState.transcriptLog) { entry in
                        TranscriptBubble(entry: entry).id(entry.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 220)
            .onChange(of: appState.transcriptLog.count) {
                if let last = appState.transcriptLog.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }
}

/// 캡처 진행 여부를 항상 한눈에 보이게 하는 배지 — "지금 녹음되고 있는지 모르겠다" 문제 대응.
private struct CaptureStatusChip: View {
    let isPlaying: Bool
    let startTime: Date?

    var body: some View {
        if isPlaying {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 5) {
                    PulsingDot()
                    Text("REC \(elapsed(now: context.date))")
                        .font(.caption.monospacedDigit().weight(.semibold))
                }
            }
            .foregroundStyle(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.12), in: Capsule())
        } else {
            HStack(spacing: 5) {
                Circle().fill(Color.secondary.opacity(0.4)).frame(width: 8, height: 8)
                Text("대기 중").font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.08), in: Capsule())
        }
    }

    private func elapsed(now: Date) -> String {
        guard let startTime else { return "0:00" }
        let seconds = max(0, Int(now.timeIntervalSince(startTime)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct PulsingDot: View {
    @State private var isDim = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .opacity(isDim ? 0.25 : 1)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isDim)
            .onAppear { isDim = true }
    }
}

/// 발화자별 말풍선 — 나(오른쪽·파랑) / 상대방(왼쪽·회색, 경고 시 주황·빨강 강조)으로 시각 분리.
private struct TranscriptBubble: View {
    let entry: TranscriptLogEntry

    private var isMe: Bool {
        entry.track == .local
    }

    var body: some View {
        HStack {
            if isMe {
                Spacer(minLength: 40)
            }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                Text(isMe ? "나" : "상대방")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Text(entry.text)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(bubbleColor, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(isMe ? .white : .primary)
                Text(entry.timestamp)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            if !isMe {
                Spacer(minLength: 40)
            }
        }
    }

    private var bubbleColor: Color {
        if isMe {
            return .blue
        }
        switch entry.level {
        case .none: return Color.gray.opacity(0.18)
        case .caution: return Color.orange.opacity(0.3)
        case .danger: return Color.red.opacity(0.3)
        }
    }
}
