import AlertPolicy
import Capture
import Detection
import Foundation
import STT

// P4-T7 (M7): 부하 테스트 — 픽스처를 실시간 페이싱으로 반복 재생하며 CPU(1코어 환산 평균)·
// 피크 메모리·처리 지연 드리프트(초반 10% vs 후반 10% 구간, STT가 실제로 실행된 청크만 평균)를
// 수집한다. whisper 모델은 실제 앱처럼 1회만 로드해 재사용한다(통화마다 재로드하지 않음).

func cpuTimeSeconds() -> Double {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    let user = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
    let sys = Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
    return user + sys
}

/// Darwin(macOS)의 ru_maxrss 단위는 바이트다(Linux는 KB — 플랫폼별 차이 주의).
func peakMemoryMB() -> Double {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    return Double(usage.ru_maxrss) / 1_000_000
}

func parseDuration() -> Double {
    guard let index = CommandLine.arguments.firstIndex(of: "--duration"),
          CommandLine.arguments.count > index + 1,
          let value = Double(CommandLine.arguments[index + 1])
    else { return 1800 }
    return value
}

struct LoadTestContext {
    let fixtures: [URL]
    let ruleEngine: RuleEngine
    let classifier: LinearClassifier
    let engine: WhisperEngine
}

func loadContext(root: URL) -> LoadTestContext? {
    let fixturesDir = root.appendingPathComponent("Tests/Fixtures/audio")
    guard let entries = try? FileManager.default.contentsOfDirectory(
        at: fixturesDir, includingPropertiesForKeys: nil
    ) else {
        print("status: FAILED — 픽스처 디렉터리를 읽을 수 없음")
        return nil
    }
    let fixtures = entries.filter { $0.pathExtension == "wav" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    guard !fixtures.isEmpty else {
        print("status: FAILED — 픽스처 0개")
        return nil
    }

    let cachesURL = try? FileManager.default.url(
        for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
    )
    guard let modelURL = cachesURL?.appendingPathComponent("CallGuard/whisper-model-cache/ggml-base.bin"),
          FileManager.default.fileExists(atPath: modelURL.path)
    else {
        print("status: FAILED — base 모델 캐시 없음 — 먼저 실행: .build/debug/MeasureSTTLatency ggml-base.bin <sha256>")
        return nil
    }
    let sttSpec = WhisperModelSpec(expectedSHA256: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe")

    guard let rulesData = try? Data(contentsOf: root.appendingPathComponent("rules.yaml")),
          let signature = try? String(contentsOf: root.appendingPathComponent("rules.yaml.sig"), encoding: .utf8)
          .trimmingCharacters(in: .whitespacesAndNewlines),
          let ruleEngine = try? RuleEngine.load(rulesData: rulesData, expectedSignature: signature)
    else {
        print("status: FAILED — rules.yaml/.sig 로드 실패")
        return nil
    }

    let modelJSONURL = root.appendingPathComponent("ml/training/model.json")
    guard FileManager.default.fileExists(atPath: modelJSONURL.path),
          let classifierModel = try? LinearClassifierModel.load(from: modelJSONURL)
    else {
        print("status: FAILED — 분류기 model.json 없음 — 먼저 실행: python3 ml/training/train.py --smoke")
        return nil
    }

    guard let engine = try? WhisperEngine(modelURL: modelURL, spec: sttSpec) else {
        print("status: FAILED — WhisperEngine 초기화 실패")
        return nil
    }

    return LoadTestContext(
        fixtures: fixtures, ruleEngine: ruleEngine,
        classifier: LinearClassifier(model: classifierModel), engine: engine
    )
}

struct LoopResult {
    let wallElapsed: Double
    let cpuElapsed: Double
    /// STT가 실제로 실행된(세그먼트를 낸) 청크만 기록 — 순수 버퍼링 스텝(대부분 0ms 근처)이
    /// 섞이면 early/late 평균이 노이즈에 휘둘려 드리프트 %가 무의미해진다.
    let latencySamples: [(elapsedS: Double, latencyMs: Double)]
    let callsCompleted: Int
}

func runLoop(context: LoadTestContext, duration: Double) async -> LoopResult? {
    let overallStart = Date()
    let cpuStart = cpuTimeSeconds()
    var latencySamples: [(elapsedS: Double, latencyMs: Double)] = []
    var callsCompleted = 0

    outer: while Date().timeIntervalSince(overallStart) < duration {
        for fixture in context.fixtures {
            guard Date().timeIntervalSince(overallStart) < duration else { break outer }
            guard let source = try? FileAudioSource(url: fixture, track: .remote) else {
                print("status: FAILED — 픽스처 로드 실패: \(fixture.lastPathComponent)")
                return nil
            }
            var transcriber = TrackTranscriber(track: .remote, engine: context.engine)
            var detection = DetectionEngine(ruleEngine: context.ruleEngine, classifier: context.classifier)
            var policy = AlertPolicy()

            do {
                for try await chunk in source.chunks() {
                    let stepStart = Date()
                    let segments = try transcriber.feed(chunk)
                    for segment in segments {
                        let score = detection.evaluate(adding: segment)
                        policy.update(with: score)
                    }
                    if !segments.isEmpty {
                        let latencyMs = Date().timeIntervalSince(stepStart) * 1000
                        latencySamples.append((Date().timeIntervalSince(overallStart), latencyMs))
                    }
                }
                if let residual = try transcriber.flush() {
                    let score = detection.evaluate(adding: residual)
                    policy.update(with: score)
                }
            } catch {
                print("status: FAILED — 재생 실패: \(fixture.lastPathComponent): \(error)")
                return nil
            }
            callsCompleted += 1
        }
    }

    return LoopResult(
        wallElapsed: Date().timeIntervalSince(overallStart),
        cpuElapsed: cpuTimeSeconds() - cpuStart,
        latencySamples: latencySamples,
        callsCompleted: callsCompleted
    )
}

func report(_ result: LoopResult) -> Int32 {
    let cpuAvgPct = result.wallElapsed > 0 ? (result.cpuElapsed / result.wallElapsed) * 100 : 0
    let peakMB = peakMemoryMB()

    let earlyWindow = result.latencySamples.filter { $0.elapsedS <= result.wallElapsed * 0.1 }.map(\.latencyMs)
    let lateWindow = result.latencySamples.filter { $0.elapsedS >= result.wallElapsed * 0.9 }.map(\.latencyMs)
    let earlyAvg = earlyWindow.isEmpty ? 0 : earlyWindow.reduce(0, +) / Double(earlyWindow.count)
    let lateAvg = lateWindow.isEmpty ? 0 : lateWindow.reduce(0, +) / Double(lateWindow.count)
    let driftPct = earlyAvg > 0 ? ((lateAvg - earlyAvg) / earlyAvg) * 100 : 0

    print("wall_elapsed_s: \(String(format: "%.1f", result.wallElapsed))")
    print("calls_completed: \(result.callsCompleted)")
    print("stt_samples: \(result.latencySamples.count) (early=\(earlyWindow.count), late=\(lateWindow.count))")
    print("cpu_avg_pct_1core: \(String(format: "%.1f", cpuAvgPct))")
    print("peak_memory_mb: \(String(format: "%.1f", peakMB))")
    print(
        "latency_drift_pct: \(String(format: "%.1f", driftPct))"
            + " (early_ms=\(String(format: "%.1f", earlyAvg)), late_ms=\(String(format: "%.1f", lateAvg)))"
    )

    let cpuOK = cpuAvgPct <= 40
    let memOK = peakMB <= 2000
    let driftOK = driftPct <= 20
    if cpuOK, memOK, driftOK {
        print("status: PASS — CPU ≤ 40% && 메모리 ≤ 2GB && 드리프트 ≤ +20%")
        return 0
    }
    print("status: FAIL — cpuOK=\(cpuOK) memOK=\(memOK) driftOK=\(driftOK)")
    return 1
}

/// 본문을 함수로 감싸 반환 시점에 WhisperEngine 등 로컬 변수가 정상 스코프 해제되게 한다 —
/// whisper.cpp의 Metal 정리 코드는 전역 스코프에서 exit()로 곧장 종료되면(디이닛 미실행)
/// 잔여 residency set에서 assert 크래시가 난다(업스트림 이슈, 재현 확인). 함수 반환 후
/// 최상위에서 exit(code)하면 스코프 해제가 먼저 끝나 안전하다.
func run() async -> Int32 {
    let duration = parseDuration()
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    guard let context = loadContext(root: root) else { return 1 }

    print("status: RUNNING — duration=\(Int(duration))s, fixtures=\(context.fixtures.count)")
    guard let result = await runLoop(context: context, duration: duration) else { return 1 }
    return report(result)
}

let exitCode = await run()
exit(exitCode)
