import AlertPolicy
import Capture
import Detection
import Foundation
import STT

/// AlertPolicy는 순수 struct라 백그라운드 파이프라인 루프와 UI([무시] 버튼)가 서로 다른
/// 컨텍스트에서 같은 인스턴스를 안전하게 갱신하려면 actor로 감싸야 한다.
actor PolicyActor {
    private var policy = AlertPolicy()

    @discardableResult
    func update(with score: RiskScore?) -> AlertLevel {
        policy.update(with: score)
    }

    func dismiss(category: RiskCategory) {
        policy.dismiss(category: category)
    }

    var dismissalLog: [RiskCategory] {
        policy.dismissalLog
    }
}

struct PipelineContext {
    let ruleEngine: RuleEngine
    let classifier: LinearClassifier
    let modelURL: URL
    let sttSpec: WhisperModelSpec
}

enum PipelineError: Error {
    case setupFailed(String)
}

func loadPipelineContext(root: URL) throws -> PipelineContext {
    let cachesURL = try? FileManager.default.url(
        for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
    )
    guard let modelURL = cachesURL?.appendingPathComponent("CallGuard/whisper-model-cache/ggml-base.bin"),
          FileManager.default.fileExists(atPath: modelURL.path)
    else {
        throw PipelineError.setupFailed("base 모델 캐시 없음 — 먼저 .build/debug/MeasureSTTLatency ggml-base.bin <sha256> 실행")
    }
    let sttSpec = WhisperModelSpec(expectedSHA256: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe")

    guard let rulesData = try? Data(contentsOf: root.appendingPathComponent("rules.yaml")),
          let signature = try? String(contentsOf: root.appendingPathComponent("rules.yaml.sig"), encoding: .utf8)
          .trimmingCharacters(in: .whitespacesAndNewlines),
          let ruleEngine = try? RuleEngine.load(rulesData: rulesData, expectedSignature: signature)
    else { throw PipelineError.setupFailed("rules.yaml/.sig 로드 실패 — 저장소 루트에서 실행했는지 확인") }

    let modelJSONURL = root.appendingPathComponent("ml/training/model.json")
    guard FileManager.default.fileExists(atPath: modelJSONURL.path),
          let classifierModel = try? LinearClassifierModel.load(from: modelJSONURL)
    else { throw PipelineError.setupFailed("분류기 model.json 없음 — 먼저 python3 ml/training/train.py --smoke 실행") }

    return PipelineContext(
        ruleEngine: ruleEngine, classifier: LinearClassifier(model: classifierModel),
        modelURL: modelURL, sttSpec: sttSpec
    )
}

/// 백그라운드에서 실행 — WhisperEngine은 이 함수 스코프 안에서만 생성·사용되고 MainActor로
/// 넘어가지 않는다(Sendable 미선언 타입, P2-T2 설계 그대로). 세그먼트 판정마다 onSegment를
/// MainActor로 호출해 UI를 갱신한다. source는 파일 재생(FileAudioSource)·실시간 캡처
/// (SystemAudioCapture) 어느 쪽이든 AudioSource 계약만 지키면 동일하게 동작한다 — Capture
/// 모듈이 애초에 이렇게 교체 가능하도록 설계됨(AGENTS.md §4).
func runPipeline(
    source: any AudioSource,
    policyActor: PolicyActor,
    onStatus: @escaping @MainActor (String) -> Void,
    onSegment: @escaping @MainActor (TranscriptSegment, RiskScore?, AlertLevel) -> Void,
    onFinished: @escaping @MainActor () -> Void
) async {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let context: PipelineContext
    do {
        context = try loadPipelineContext(root: root)
    } catch {
        await onStatus("설정 실패: \(error)")
        await onFinished()
        return
    }

    guard let engine = try? WhisperEngine(modelURL: context.modelURL, spec: context.sttSpec) else {
        await onStatus("음성 인식 엔진 초기화 실패")
        await onFinished()
        return
    }

    var transcriber = TrackTranscriber(track: source.track, engine: engine)
    var detection = DetectionEngine(ruleEngine: context.ruleEngine, classifier: context.classifier)

    do {
        for try await chunk in source.chunks() {
            for segment in try transcriber.feed(chunk) {
                let score = detection.evaluate(adding: segment)
                let level = await policyActor.update(with: score)
                await onSegment(segment, score, level)
            }
        }
        if let residual = try transcriber.flush() {
            let score = detection.evaluate(adding: residual)
            let level = await policyActor.update(with: score)
            await onSegment(residual, score, level)
        }
    } catch let error as CaptureError {
        if let guidance = PermissionGuidance.from(error) {
            await onStatus("\(guidance.title) \(guidance.instruction)")
        } else {
            await onStatus("캡처 실패: \(error)")
        }
    } catch {
        await onStatus("재생/전사 실패: \(error)")
    }

    await onFinished()
}

/// 로컬(본인) 트랙 전용 — 전사만 하고 탐지에는 넣지 않는다(rules.yaml 키워드가 상대방 발화
/// 패턴이라 본인 트랙에서 매칭될 근거가 없음). 화자 분리(F-S1 계열) 표시용.
func runTranscriptionOnlyPipeline(
    source: any AudioSource,
    onSegment: @escaping @MainActor (TranscriptSegment) -> Void
) async {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    guard let context = try? loadPipelineContext(root: root),
          let engine = try? WhisperEngine(modelURL: context.modelURL, spec: context.sttSpec)
    else { return }

    var transcriber = TrackTranscriber(track: source.track, engine: engine)
    do {
        for try await chunk in source.chunks() {
            for segment in try transcriber.feed(chunk) {
                await onSegment(segment)
            }
        }
        if let residual = try transcriber.flush() {
            await onSegment(residual)
        }
    } catch {
        // 로컬 트랙은 보조 정보 — 실패해도 원격 트랙 세션은 계속 진행한다.
    }
}
