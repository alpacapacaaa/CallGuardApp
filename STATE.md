# STATE
## 현재 태스크
P4-T7 (운영자 지시: 속도·토큰 절약 우선 — 이하 로그 최소화)
## 완료 태스크
- [x] P4-T6 (2026-08-11, 커밋 예정 — MeasureE2ELatency CLI + scripts/measure_latency.sh --stage e2e. base 모델, 픽스처 10×10=100런, 경고 발생 20건. **실측: p50=209.7ms p95=713.8ms — M1 목표(p50≤2.0s/p95≤4.0s) 여유 있게 통과**. e2e-latency.csv(gitignore, 재생성 아티팩트))
- [x] P4-T2 (2026-08-11, commit 0601124 — AlertViewModel+AlertViews(메뉴바/주의배너/위험패널) + RenderUIStates CLI(ImageRenderer→PNG, 신규 의존성 없음). docs/ui/{menubar-none,caution-banner,danger-panel}.png 생성. fast 테스트 4건, ci_fast 전부 통과)
- [x] P4-T3 (2026-08-11, commit a99f886 — Sources/Onboarding/SelfDiagnosis.swift: FileAudioSource로 내장 샘플(normal-delivery-01.wav) 재생→Capture/STT/Detection/AlertPolicy 4단계 통과 여부 보고. docs/onboarding.md(환경 진단 체크리스트+권한 가이드 링크). slow 통합 테스트 SelfDiagnosisTests 1건 통과(tiny 모델 캐시 재사용, 4.8초)
- [x] P4-T5 (2026-08-11, 커밋 예정 — AlertPolicy에 SensitivityPreset(low/medium/high, F-S3) + dismissalLog(F-S2 로컬 오탐 목록) 추가(medium=기존 임계값 그대로, 회귀 없음). Sources/AlertPolicy/SessionReport.swift(F-S1: 타임라인+근거+오탐목록 SessionReportBuilder). slow Flow 통합 테스트 2건(세션 전체 흐름, 민감도별 승격 차이) + fast 단위 테스트 2건 추가, ci_fast 전부 통과)
- [x] P0-T1 (2026-08-09, commit 7ac9e04)
- [x] P0-T2 (2026-08-10, commit 0ea0725)
- [x] P0-T3 (2026-08-10, commit 1a80fb8)
- [x] P0-T4 (2026-08-10, commit 7136418)
- [x] P0-T5 (2026-08-10, commit da8f968)
- [x] P1-T2 (2026-08-10, commit 2508ac6)
- [x] P1-T4 (2026-08-10, commit 7a56f62)
- [x] P1-T5 (2026-08-10, commit 8e594c3)
- [x] P2-T1 (2026-08-10, commit 9489d0c)
- [x] P3-T2 (2026-08-10, commit c01101e — P2-T2가 G10 대기라 [병렬 가능] 경로로 전진)
- [x] P4-T1 (2026-08-11, commit e7e9407 — F-M8 동의 게이트를 SessionController 리듀서에 구조적으로 포함)
- [x] P4-T4 (2026-08-11, commit caf50c9 — GRDB 운영자 승인 후 착수, 3개 DoD 테스트 전부 통과)
- [x] P2-T2 (2026-08-11, commit 1d4f4f2 — whisper.cpp, Metal 실추론 확인)
- [x] P2-T3 (2026-08-11, commit a3f6ffb — TrackTranscriber)
- [x] P2-T4 (2026-08-11, commit 4ecdd5b — MeasureSTTLatency, p50=183.8ms p95=553.4ms)
- [x] P2-T5 (2026-08-11, commit 9146357 — CER 측정, tiny CER=0.619)
- [x] P2-T6 (2026-08-11, 커밋 예정 — docs/stt-benchmark.md. tiny/base/small 3종 비교: p95 전부 1.5s 예산 이내(540~570ms), CER은 base 0.458 최소로 base 채택. **주의: base도 PRD 목표(≤15%) 대비 3배 높음 — G-2 게이트에서 운영자 판정 필요, 원인 미조사(TTS 픽스처 특성/모델 한계/구두점 비교 오류 등 후보만 기록)**)
- [x] P3-T1 (2026-08-11, 커밋 예정 — ml/eval/run.py 로더+--dry-run. 현재 10건(피싱5/정상5)만, 목표(50/100)는 실데이터 필요해 운영자 항목으로 명시 후 계속 진행)
- [x] P3-T3 (2026-08-11, 커밋 예정 — ml/training/train.py: TF-IDF+로지스틱회귀 순수 Python(외부 의존성 0, G10 비대상 — sklearn 안 씀). --smoke: train8/val2, F1=1.0(스모크라 무의미, 명시함). model.json 산출(gitignore — 재생성 가능 아티팩트, stt-latency.csv와 동일 취급))
- [x] P3-T4 (2026-08-11, 커밋 예정 — Sources/Detection/LinearClassifier.swift: Python train.py와 동일 TF-IDF+시그모이드 알고리즘 직접 구현. 테스트: Swift 점수가 Python scores.json과 완전 일치(오차<1e-6), 추론 0.001초(예산 300ms 여유))
- [x] P3-T5 (2026-08-11, 커밋 예정 — DetectionEngine: 60s 슬라이딩 윈도, 룰+분류기 결합(value=max), 룰 무매칭 시 nil 반환(category 비옵셔널이라 근거 없는 카테고리 방지). slow 테스트 2건 통과)
- [x] P3-T6 (2026-08-11, 커밋 예정 — AlertPolicy 상태머신: 0.5/0.8 임계+히스테리시스(하강 임계 0.4/0.7), dismiss(category:)로 세션 내 동일 카테고리 재경고 억제. fast 테스트 5건)
- [x] P3-T7 (2026-08-11, 커밋 예정 — EvaluateDetection CLI(STT→Detection→AlertPolicy 전 구간) + ml/eval/run.py 전체평가 모드. **실측(현재 10건 스모크): recall=0.400 precision=1.000 fpr=0.000 first_alert_avg=5.0s.** 미탐 3건 전부 STT 인식 오류로 룰 키워드 불일치 추정(G-2에서 이미 CER 이슈 플래그함) — G-3에서 함께 판단 필요**)
## G-3 게이트: STOP 자료 준비 완료(Phase 3 에이전트 큐 소진)
Recall 0.400은 중간 기준(≥0.80) 미달이지만 **데이터 10건(목표 50/100 대비)+G-2 CER 이슈 미해결 상태의 조합 결과** — 현재 수치를 최종 판정으로 쓰기엔 이르다. 운영자 판단 필요 사항:
1. G-2(STT CER)와 G-3(Recall)를 묶어서 볼지 — CER이 근본 원인이면 STT 개선이 우선일 수 있음
2. 평가셋 실데이터(P3-T1) 확보 없이 G-3 확정 가능한지
3. 위 결정에 따라 P3-T8(개선 이터레이션) 방향 지정
Phase 3의 에이전트 큐(P3-T2~T7)는 여기서 소진 — P3-T8은 운영자가 방향을 지정해야 착수 가능(plan.md).
## G-2 게이트: STOP 자료 준비 완료
STT 확정 판정 준비됨(docs/stt-benchmark.md) — **판정은 운영자**. 지연은 3종 다 통과, CER 미달이 쟁점. 하네스 규칙(plan.md 리스크표: "P2·P3는 픽스처 기반이므로 계속 전진")에 따라 게이트 확정 대기 없이 Phase 3로 계속 진행함.
## 작업 메모 (현재 태스크의 세부 체크리스트)
P2-T2 완료 체크리스트:
- [x] 조사(AGENTS.md §9 — API 존재 확인 의무): ggml-org/whisper.cpp 저장소엔 루트 Package.swift가 없음(gh api로 직접 확인). ggerganov/whisper.spm·exPHAT/SwiftWhisper 둘 다 2024-05 이후 정지, Metal 명시적 미지원(whisper.spm 코멘트: "TODO: make Metal work") — 채택 안 함
- [x] **채택한 방식**: whisper.cpp 공식 GitHub Release 자산인 `whisper-v1.9.2-xcframework.zip`(2026-08-04 발행, build-xcframework.sh 산출물 — Metal·Accelerate 링크가 module.modulemap에 이미 포함된 것을 압축 해제해 직접 확인)을 `.binaryTarget(url:checksum:)`으로 Package.swift에 추가. 체크섬은 `swift package compute-checksum`으로 직접 산출(af74fed1...)
- [x] whisper.h를 실제로 읽고 심볼 확인(추측 금지, AGENTS.md §9): whisper_context_default_params/whisper_init_from_file_with_params/whisper_full_default_params(WHISPER_SAMPLING_GREEDY)/whisper_full/whisper_full_n_segments/whisper_full_get_segment_text/whisper_free — 전부 실제 헤더에서 확인 후 사용, 컴파일 1차 성공
- [x] Sources/STT/{STTError,WhisperModelSpec,WhisperEngine}.swift — WhisperModelSpec(SHA256 검증, 불일치 시 로드 거부) + WhisperEngine(단발 추론 전용, 트랙별 스트리밍은 P2-T3 범위라 미포함)
- [x] **환경 이슈 발견·해결**: `swift build`가 binaryTarget 다운로드 시 macOS 키체인의 무관한 github.com 항목 조회로 실패(status -128). `--disable-keychain`으로 우회 확인 → scripts/ci_fast.sh에 방어적으로 반영(다운로드 캐시 이후엔 영향 없음)
- [x] Tests/CallGuardFastTests/WhisperModelSpecTests.swift 3건(fast, 네트워크 불요): 해시 불일치 거부·일치 시 통과·대소문자 무관
- [x] Tests/CallGuardSlowTests/WhisperEngineTests.swift 2건(slow, 네트워크 필요): ggml-tiny(~75MB)+jfk.wav를 최초 1회 다운로드해 `~/Library/Caches/CallGuard/whisper-model-cache`에 캐시(저장소 커밋 안 함, G5) — **실제 Metal 추론으로 영어 샘플 전사 성공(Apple M5 GPU 인식, 14.7초)** + 변조 모델 로드 거부
- [x] swiftlint 0 위반, swiftformat 0/53(라인 길이 3건 수정)
## 마지막 DoD 실행 결과 (원문)
```
$ swift test --filter WhisperModelSpecTests   (fast, 네트워크 불요)
✔ Test rejectsHashMismatch() passed
✔ Test acceptsMatchingHash() passed
✔ Test hashComparisonIsCaseInsensitive() passed
✔ Test run with 3 tests in 1 suite passed

$ swift test --filter WhisperEngineTests   (slow, 네트워크 필요 — DoD 항목)
whisper_backend_init_gpu: found GPU device 0: MTL0 (type: 1, cnt: 0)
ggml_metal_init: found device: Apple M5
✔ Test transcribesSampleAudio() passed after 14.707 seconds.
✔ Test rejectsTamperedModelBeforeLoading() passed.
✔ Test run with 2 tests in 1 suite passed after 14.707 seconds.

$ ./scripts/ci_fast.sh
==> ci_fast: 전 단계 통과 (0/53 files require formatting, swiftlint 0 위반)
```
DoD "단발 추론 테스트 통과 + 해시 불일치 시 로드 거부 테스트 통과" 둘 다 충족.
## 미해결 이슈 / 다음 세션 지시
- **운영자 지시(2026-08-10): 스코프 축소** — 파일 재생 입력 + 경량 분류기. PRD.md/plan.md/AGENTS.md 반영 완료(git log 참조).
- **Must 우선 스코프 결정(운영자 승인, 유효)**: 시연 가능 버전까지 Must(F-M1~F-M8) 임계경로 우선.
- **G10 승인 2건 모두 반영 완료**: GRDB(P4-T4) · whisper.cpp(P2-T2). 남은 G10 대상 신규 의존성 없음 — 이후 태스크는 당분간 의존성 승인 없이 진행 가능.
- **다음 태스크 P2-T3**(트랙별 스트리밍 STT): remote/local 독립 WhisperEngine 인스턴스, TranscriptSegment 방출. 의존 P2-T1·P2-T2·P0-T5 전부 충족. slow 테스트: 픽스처 리플레이 → 두 트랙 전사 비혼합·순서 보장. **주의**: WhisperEngine은 현재 Sendable 미선언(whisper_context 동시 접근 안전하지 않음, whisper.h 명시) — 트랙별 "독립 인스턴스"라면 트랙마다 별도 WhisperEngine을 만들면 되므로 자연히 격리되지만, 실제 스트리밍 동시성 설계(actor화 여부)는 이 태스크에서 결정 필요
- **모델 선택**: 지금은 tiny로 검증만 함(속도 우선). P2-T6에서 base/small과 지연·CER 벤치마크 후 최종 모델 확정 — P2-T3 진행 시에도 tiny로 계속하다가 P2-T6에서 교체 권장(모델 SHA256는 WhisperModelSpec에 중앙화돼 있어 교체 지점 명확)
- 엔진 노트(2026-08-10~11): Claude Code Pro 구독 세션으로 P2-T1·P3-T2·P4-T1·P4-T4·P2-T2 다섯 태스크 연속 실행 — Qwen 하네스에서 첫 전환. whisper.cpp가 예상대로 가장 무거웠지만(공식 SwiftPM 패키지 부재 확인 → XCFramework 릴리즈 자산 발견 → 키체인 이슈 진단·우회까지) 5시간 창 초과 없이 완료. 지금까지 병목은 토큰/시간이 아니었음 — G10 결정 대기 시간이 유일한 지연 요인이었고 이제 해소됨.
- **CHECKPOINT-0(운영자) 검수 대기** — Phase 0 부트스트랩 완료 상태 유지
- 환경 노트: 로컬 python3는 3.12.8(§4는 ml 툴링 3.11 전제) — ml venv·의존성 구성은 P3-T1 시점에 3.11로 구축(G10 절차)
## STOP 보고 (운영자 확인 대기)
- CHECKPOINT-0: Phase 0 부트스트랩 5태스크 전부 DoD 통과로 완료 — 운영자 검수 대기(하네스 루프 정상 동작 여부 판정)
- ~~[R1/P1-T3] 실검증 패키지 준비 완료 — 운영자 수행 대기...~~ **해소(2026-08-10)**: 스코프 변경으로 R1 검증 불필요. plan.md Phase 1 참조
- [P1-T2] G6 해석 확인 요청(참고용 — P1-T2는 완료·유지 상태, 라이브 캡처 F-C4 재개 시에만 재소집 필요): SCK에는 비디오 캡처 완전 비활성화 속성이 없음(0×0 구성은 -3812 거부, 구성 변형 5종 실측). 에이전트 구현 = 최소 표면(2×2)·커서 없음·최저 프레임 간격 + 비디오 출력(.screen) 미등록 → 비디오 프레임이 프로세스로 전달되는 경로 부재(프로브: videoBuffers=0). 이것이 G6 "비디오 캡처 활성화 금지"를 충족하는지 운영자 판정 필요 — 불인정 시 P1-T2 재설계(대안 경로는 G10·큐 수정 사항)
