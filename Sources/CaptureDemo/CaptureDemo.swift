import Capture
import Foundation

/// P1-T2·P1-T4 스파이크 CLI: 트랙 2개 동시 캡처 → WAV 저장.
/// remote = SCK 시스템 오디오(상대방), local = AVAudioEngine 마이크(본인) — AGENTS.md §4.
/// 세션 1회당 --out-dir 아래 remote.wav·local.wav 2파일을 만든다(P1-T4 DoD).
/// 모든 출력은 길이·샘플 수 등 캡처 통계만 — 오디오 내용을 출력하지 않는다(G1).
/// 종료코드: 0 성공 / 1 캡처 실패 / 3 화면녹화 권한 거부 / 4 마이크 권한 거부 / 64 사용법 오류.
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

        let outDir = URL(fileURLWithPath: (options.outputDir as NSString).expandingTildeInPath, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        } catch {
            writeError("출력 디렉토리를 만들 수 없음: \(outDir.path)")
            return 1
        }

        let remoteSource = SystemAudioCapture()
        let micSource: MicAudioCapture
        do {
            micSource = try await MicAudioCapture()
        } catch let error as CaptureError {
            return report(error, outputPath: outDir.path)
        } catch {
            writeError("캡처 실패: \(error)")
            return 1
        }

        return await runSession(
            remoteSource: remoteSource,
            micSource: micSource,
            outDir: outDir,
            seconds: options.seconds
        )
    }

    /// 트랙 2개 동시 캡처 세션 — 한 트랙의 실패는 태스크 그룹 취소로 세션 전체를 중단한다.
    static func runSession(
        remoteSource: SystemAudioCapture,
        micSource: MicAudioCapture,
        outDir: URL,
        seconds: Int
    ) async -> Int32 {
        print("캡처 시작: \(seconds)s → \(outDir.path)/{remote,local}.wav  (Ctrl-C로 조기 종료)")
        let startedAt = Date()
        do {
            let results = try await withThrowingTaskGroup(of: TrackResult.self) { group in
                group.addTask {
                    try await captureTrack(
                        source: remoteSource, to: outDir, seconds: seconds, startedAt: startedAt
                    )
                }
                group.addTask {
                    try await captureTrack(
                        source: micSource, to: outDir, seconds: seconds, startedAt: startedAt
                    )
                }
                var finished: [TrackResult] = []
                for try await result in group {
                    finished.append(result)
                }
                return finished
            }
            for result in results.sorted(by: { $0.track.rawValue < $1.track.rawValue }) {
                print(String(
                    format: "완료: [%@] %.1fs (%d프레임 @ %dHz) → %@",
                    result.track.rawValue, Double(result.frames) / Double(result.sampleRate),
                    result.frames, result.sampleRate,
                    outDir.appendingPathComponent(result.track.captureFileName).path
                ))
            }
            return 0
        } catch let error as CaptureError {
            return report(error, outputPath: outDir.path)
        } catch {
            writeError("캡처 실패: \(error)")
            return 1
        }
    }

    /// 트랙 1개 캡처 → WAV 1파일. 파일 수명주기를 이 태스크가 소유한다(WavWriter 비전송).
    static func captureTrack(
        source: any AudioSource,
        to outDir: URL,
        seconds: Int,
        startedAt: Date
    ) async throws -> TrackResult {
        let url = outDir.appendingPathComponent(source.track.captureFileName)
        let writer = try WavWriter(url: url, sampleRate: source.sampleRate)
        var lastReportedSecond = -1
        do {
            for try await chunk in source.chunks() {
                // 트랙 태깅 계약(P1-T4) — 소스와 다른 태그가 도착하면 조용히 섞지 않고 명시 실패.
                guard chunk.track == source.track else {
                    throw CaptureError.captureFailed(
                        detail: "stage=tag code=mismatch track=\(source.track.rawValue)"
                    )
                }
                try writer.append(chunk.samples)
                let elapsed = Date().timeIntervalSince(startedAt)
                if Int(elapsed) > lastReportedSecond {
                    lastReportedSecond = Int(elapsed)
                    print("[\(source.track.rawValue)] 캡처 중… \(Int(elapsed))s/\(seconds)s")
                }
                if elapsed >= Double(seconds) || stopRequested == 1 {
                    break
                }
            }
            try writer.close()
        } catch {
            try? writer.close()
            if writer.framesWritten == 0 {
                try? FileManager.default.removeItem(at: url)
            }
            throw error
        }
        return TrackResult(track: source.track, frames: writer.framesWritten, sampleRate: source.sampleRate)
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
        case .microphoneDenied:
            writeError("""
            마이크 권한이 없습니다.
            시스템 설정 → 개인 정보 보호 및 보안 → 마이크에서 이 데모를 실행한
            상위 앱(예: 터미널)을 허용한 뒤 다시 실행하세요. (종료코드 4)
            """)
            return 4
        default:
            writeError("캡처 실패: \(error) (출력 위치: \(outputPath))")
            return 1
        }
    }

    static func writeError(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    static let usage = """
    사용법: CaptureDemo [--seconds N] [--out-dir DIR]
      --seconds N    캡처 길이(초), 1–600 (기본 10)
      --out-dir DIR  트랙별 WAV(remote.wav·local.wav) 저장 디렉토리 (기본 현재 디렉토리)
    종료코드: 0 성공 / 1 캡처 실패 / 3 화면녹화 권한 거부 / 4 마이크 권한 거부 / 64 사용법 오류
    참고: 최초 실행 시 TCC 화면녹화·마이크 권한 프롬프트가 나타납니다. 거부하면 해당
          권한 안내 후 종료코드 3·4로 종료되며, 크래시는 발생하지 않습니다.
    """

    /// 트랙 1개의 캡처 결과 요약 — 출력·정렬에만 사용(G1-safe 통계).
    struct TrackResult: Sendable {
        let track: AudioTrack
        let frames: Int
        let sampleRate: Int
    }

    private struct Options {
        var seconds = 10
        var outputDir = "."

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
                case "--out-dir":
                    index += 1
                    guard index < arguments.count, !arguments[index].isEmpty else { return nil }
                    options.outputDir = arguments[index]
                default:
                    return nil
                }
                index += 1
            }
            return options
        }
    }
}
