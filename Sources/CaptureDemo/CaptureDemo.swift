import Capture
import Foundation

/// P1-T2 스파이크 CLI: 시스템 오디오(SCK, 오디오 전용) → 48kHz PCM 모노 WAV.
/// 음악·통화 오디오 재생 중 실행 → 생성 파일 재생으로 검증한다(DoD 운영자 항목).
/// 모든 출력은 길이·샘플 수 등 캡처 통계만 — 오디오 내용을 출력하지 않는다(G1).
/// 종료코드: 0 성공 / 1 캡처 실패 / 3 화면녹화 권한 거부 / 64 사용법 오류.
@main
enum CaptureDemo {
    /// C 시그널 핸들러는 상태를 캡처할 수 없다 — async-signal-safe 관용(sig_atomic_t 전역)으로 종료 요청 전달.
    static var stopRequested: sig_atomic_t = 0

    static func main() async {
        await exit(run(arguments: Array(CommandLine.arguments.dropFirst())))
    }

    static func run(arguments: [String]) async -> Int32 {
        if arguments.contains("--help") || arguments.contains("-h") {
            print(usage)
            return 0
        }
        guard let options = Options.parse(arguments) else {
            writeError("인자 오류\n\n\(usage)")
            return 64
        }

        signal(SIGINT) { _ in CaptureDemo.stopRequested = 1 }

        let outputURL = URL(fileURLWithPath: (options.outputPath as NSString).expandingTildeInPath)
        let source = SystemAudioCapture()
        print("캡처 시작: \(options.seconds)s → \(outputURL.path)  (Ctrl-C로 조기 종료)")

        let writer: WavWriter
        do {
            writer = try WavWriter(url: outputURL, sampleRate: source.sampleRate)
        } catch {
            writeError("출력 파일을 만들 수 없음: \(outputURL.path)")
            return 1
        }

        let startedAt = Date()
        do {
            try await writeCapture(writer: writer, source: source, seconds: options.seconds, startedAt: startedAt)
            try writer.close()
        } catch let error as CaptureError {
            try? writer.close()
            if writer.framesWritten == 0 {
                try? FileManager.default.removeItem(at: outputURL)
            }
            return report(error, outputPath: outputURL.path)
        } catch {
            try? writer.close()
            writeError("캡처 실패: \(error)")
            return 1
        }

        let capturedSeconds = Double(writer.framesWritten) / Double(source.sampleRate)
        print(String(
            format: "완료: %.1fs 캡처 (%d프레임 @ %dHz) → %@",
            capturedSeconds, writer.framesWritten, source.sampleRate, outputURL.path
        ))
        return 0
    }

    /// 길이 도달·조기 종료 요청까지 캡처 샘플을 WAV에 기록한다. 진행 출력은 초 단위(G1-safe).
    static func writeCapture(
        writer: WavWriter,
        source: SystemAudioCapture,
        seconds: Int,
        startedAt: Date
    ) async throws {
        var lastReportedSecond = -1
        for try await chunk in source.chunks() {
            try writer.append(chunk.samples)
            let elapsed = Date().timeIntervalSince(startedAt)
            if Int(elapsed) > lastReportedSecond {
                lastReportedSecond = Int(elapsed)
                print("캡처 중… \(Int(elapsed))s/\(seconds)s")
            }
            if elapsed >= Double(seconds) || stopRequested == 1 {
                break
            }
        }
    }

    static func report(_ error: CaptureError, outputPath: String) -> Int32 {
        switch error {
        case .screenCaptureDenied:
            writeError("""
            화면녹화 권한이 없습니다.
            시스템 설정 → 개인 정보 보호 및 보안 → 화면 녹화에서 이 데모를 실행한
            상위 앱(예: 터미널)을 허용한 뒤 다시 실행하세요. (종료코드 3)
            """)
            return 3
        default:
            writeError("캡처 실패: \(error) (출력 파일: \(outputPath))")
            return 1
        }
    }

    static func writeError(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    static let usage = """
    사용법: CaptureDemo [--seconds N] [--out PATH]
      --seconds N   캡처 길이(초), 1–600 (기본 10)
      --out PATH    저장할 WAV 경로 (기본 remote.wav)
    종료코드: 0 성공 / 1 캡처 실패 / 3 화면녹화 권한 거부 / 64 사용법 오류
    참고: 최초 실행 시 TCC 화면녹화 권한 프롬프트가 나타납니다. 거부하면 안내 후
          종료코드 3으로 종료되며, 크래시는 발생하지 않습니다.
    """

    private struct Options {
        var seconds = 10
        var outputPath = "remote.wav"

        static func parse(_ arguments: [String]) -> Options? {
            var options = Options()
            var index = 0
            while index < arguments.count {
                switch arguments[index] {
                case "--seconds":
                    index += 1
                    guard index < arguments.count,
                          let value = Int(arguments[index]), (1 ... 600).contains(value)
                    else { return nil }
                    options.seconds = value
                case "--out":
                    index += 1
                    guard index < arguments.count, !arguments[index].isEmpty else { return nil }
                    options.outputPath = arguments[index]
                default:
                    return nil
                }
                index += 1
            }
            return options
        }
    }
}
