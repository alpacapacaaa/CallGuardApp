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
        // minHeight를 넉넉하게 잡아 창이 처음부터 자막을 보여줄 공간을 확보한다 — 콘텐츠가
        // 작을 때(대기 화면)만 딱 맞게 줄어들던 이전 방식은, 실시간 캡처 중 창이 비활성 상태일
        // 때 자동 리사이즈가 곧바로 반영되지 않아 자막 칸이 아예 안 보이다가 "중지"를 눌러야
        // (창과 다시 상호작용해야) 뒤늦게 펼쳐지는 문제가 있었다. 기본 높이를 넉넉히 잡아두면
        // 그 리사이즈 타이밍에 기대지 않아도 된다.
        // alignment: .leading — 지정 안 하면 기본값 .center라, 내부 콘텐츠가 이 폭보다
        // 커지는 경우(예: 배너 폭 실수) 전체가 가운데 정렬되며 왼쪽으로 밀려 보이는 문제가
        // 있었다. 왼쪽 고정으로 방어해 향후 폭 불일치가 생겨도 레이아웃이 안 흔들리게 한다.
        .frame(width: 340, alignment: .leading)
        .frame(minHeight: 600, alignment: .top)
    }

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(appState.transcriptLog) { entry in
                        TranscriptBubble(entry: entry, showSpeakerLabel: appState.isLiveCapture).id(entry.id)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 400)
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
/// showSpeakerLabel이 false면(파일 재생) 이 구분을 아예 안 보여준다 — 파일 재생은 마이크·
/// 시스템 오디오가 실제로 나뉘어 들어오는 게 아니라 항상 트랙 하나(.remote)뿐이라, "상대방"
/// 라벨을 붙이면 진짜 화자 분리가 된 것처럼 오인시킨다.
private struct TranscriptBubble: View {
    let entry: TranscriptLogEntry
    let showSpeakerLabel: Bool

    private var isMe: Bool {
        showSpeakerLabel && entry.track == .local
    }

    var body: some View {
        HStack {
            if isMe {
                Spacer(minLength: 40)
            }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                if showSpeakerLabel {
                    Text(isMe ? "나" : "상대방")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
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
