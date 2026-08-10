# STATE
## 현재 태스크
P4-T1
## 완료 태스크
- [x] P0-T1 (2026-08-09, commit 7ac9e04)
- [x] P0-T2 (2026-08-10, commit 0ea0725)
- [x] P0-T3 (2026-08-10, commit 1a80fb8)
- [x] P0-T4 (2026-08-10, commit 7136418)
- [x] P0-T5 (2026-08-10, commit da8f968)
- [x] P1-T2 (2026-08-10, commit 2508ac6)
- [x] P1-T4 (2026-08-10, commit 7a56f62)
- [x] P1-T5 (2026-08-10, commit 8e594c3)
- [x] P2-T1 (2026-08-10, 커밋 예정 — Claude Code Pro 세션으로 실행, Qwen 하네스에서 엔진 전환 후 첫 태스크)
- [x] P3-T2 (2026-08-10, 커밋 예정 — P2-T2가 G10(외부 의존성) 승인 대기라 [병렬 가능] 경로로 전진)
## 작업 메모 (현재 태스크의 세부 체크리스트)
P3-T2 완료 체크리스트:
- [x] 설계: RuleSet(고정 스키마 전용 최소 YAML 파서, 직접 구현) + RuleSignature(CryptoKit SHA256 — 시스템 프레임워크라 G10 비대상) + RuleEngine(load 시 서명 검증, evaluate 키워드 매칭)
- [x] rules.yaml(저장소 루트, 카테고리 5종 각 5개 키워드) + rules.yaml.sig(SHA256 hex) 작성
- [x] Sources/Detection/{RuleSet,RuleSignature,RuleEngine}.swift 구현
- [x] Tests/CallGuardFastTests/RuleEngineTests.swift 12건: 5카테고리 로드 검증, 서명 불일치 거부, 카테고리별 양성 1+음성 1(총 10건) — 실제 rules.yaml/.sig를 #filePath로 직접 로드(픽스처 드리프트 방지)
- [x] scripts/check_rule_coverage.sh: rules.yaml 룰 ID 전부가 테스트 파일에서 문자열로 참조되는지 grep 검사, exit 0/1 규약. macOS BSD grep은 `\s` 미지원 — `[[:space:]]`로 수정
- [x] swiftlint 0 위반(순환복잡도·함수 길이 위반 2건 → Builder 구조체로 분리해 해소), swiftformat 0/42(hoistTry·docComments 등 4건 자동 수정)
## 마지막 DoD 실행 결과 (원문)
```
$ swift test --filter RuleEngineTests
◇ Suite RuleEngineTests started.
✔ Test rejectsSignatureMismatch() passed after 0.001 seconds.
✔ Test loadsAllFiveCategories() passed after 0.001 seconds.
✔ Test impersonationAuthorityPositive/Negative() passed
✔ Test accountTransferPositive/Negative() passed
✔ Test appInstallLurePositive/Negative() passed
✔ Test personalInfoDemandPositive/Negative() passed
✔ Test threatUrgencyPositive/Negative() passed
✔ Test run with 12 tests in 1 suite passed after 0.001 seconds.

$ ./scripts/check_rule_coverage.sh
==> check_rule_coverage: 전 룰 커버됨
(exit 0)

$ ./scripts/ci_fast.sh
==> ci_fast: 전 단계 통과 (0/42 files require formatting, swiftlint 0 위반)
```
P2-T1 DoD 원문은 이 문서의 이전 리비전(git log STATE.md 이력 참조) — 요약: PreprocessTests 8/8 통과, 청크 경계 오차 ≤50ms 검증 포함, ci_fast 통과.
## 미해결 이슈 / 다음 세션 지시
- **운영자 지시(2026-08-10, 최신): 스코프 축소 — ① 입력을 파일 재생(FileAudioSource) 기반으로 확정, 라이브 SCK/Continuity 캡처는 Could(F-C4)로 격하 ② 2차 탐지 분류기를 KoBERT+CoreML에서 경량 선형 분류기(TF-IDF+로지스틱회귀, Swift 인프로세스 직접 구현)로 대체.** 토큰·시간 예산 제약(로컬 모델 하네스)에 따른 결정. 상세는 PRD.md §2/F-M1/F-M2/F-M4/§6(R1)/§7, plan.md Phase 1(보류)·P3-T3/T4·P4-T1, AGENTS.md §4에 반영 완료. 이 항목이 아래 R1/G-1 관련 STOP 보고를 대체한다 — R1 검증은 더 이상 필요 없음.
- **(대체됨, 하위 호환 기록) 운영자 지시(2026-08-10, 구): 가속 방향 = ① R1 실검증 지금 준비 ② Must만 데모 우선.** 아래 두 항목은 그 구 지시의 산출물(참고용, R1 관련 부분은 위 최신 지시로 무효화됨)
- ~~R1 턴키 패키지 준비 완료(에이전트)~~ **무효화(2026-08-10)**: 스코프 변경으로 R1 패키지 자체가 불필요. `docs/env-checklist.md`·`docs/spike-r1-report.md`는 파일 상단에 보류 표시만 남기고 유지(F-C4 재개 시 재사용)
- **Must 우선 스코프 결정(운영자 승인, 유효)**: 시연 가능 버전까지 Must(F-M1~F-M8) 임계경로 우선 전진, Should(F-S1·S2·S3·S5·S6)·Could는 후순위 유보. 큐 자체 수정은 운영자 권한 — 에이전트는 태스크 선택 시 Must 임계경로(P2-T1→T2→T3→…→P4 경고 UI·동의 게이트)를 우선하는 것으로 반영
- **P2-T1 완료(2026-08-10)**: Preprocess 모듈(Resampler·VoiceActivityDetector·PreprocessPipeline·PreprocessedChunk) 구현, 외부 DSP 의존성 0건. DoD 통과(위 원문 참조)
- **P2-T2 STOP 대기**(whisper.cpp 통합): Metal 빌드·SwiftPM 래핑·모델 파일 SHA256 고정·검증 로직. **외부 의존성(whisper.cpp) 추가가 필요 — G10 대상, 운영자 승인 전 착수 금지.** 승인 시 필요 정보: 설치 방식(git submodule+소스 빌드 vs 사전빌드 XCFramework vs SwiftPM 패키지), 모델 파일 출처·해시 고정 대상(base/small 중 P2-T6에서 확정 예정이라 우선 base로 임시 착수 가능성 있음)
- **P3-T2 완료(2026-08-10)**: RuleEngine(rules.yaml 서명 검증+5카테고리 키워드 매칭) 구현. P2-T2가 G10 대기라 [병렬 가능] 경로로 전진(plan.md 규칙 그대로). DoD 통과(위 원문 참조)
- **다음 태스크 P4-T1**(세션 시작/종료, v2 스코프): FileAudioSource 재생 시작=세션 시작, EOF=세션 종료, 수동 중지 버튼. 의존=P0-T3 only(충족) — G-1 폐지로 Phase1 의존 사슬에서 해방됨(plan.md 참조). Sources/Session(현재 placeholder)에 구현. fast 테스트: 재생 시작/EOF 이벤트 시퀀스 → 세션 시작/종료 전이 검증
- 엔진 노트(2026-08-10): P2-T1·P3-T2 둘 다 Claude Code Pro 구독 세션으로 실행 — Qwen 하네스에서 처음 전환. 실측: 두 태스크(Preprocess 4파일+테스트8건, RuleEngine 3파일+rules.yaml+테스트12건+커버리지스크립트, 린트 위반 총 6건 수정 포함)를 CI 전체 통과까지 완료하는 데 5시간 창의 극히 일부만 소요 — Qwen 대비 체감 훨씬 빠름. 다음 세션에서도 계속 관찰해 P2-T2(whisper.cpp, 무거운 태스크) 승인 시점의 페이스 재판단 필요
- **CHECKPOINT-0(운영자) 검수 대기** — Phase 0 부트스트랩 완료 상태 유지
- 환경 노트: 로컬 python3는 3.12.8(§4는 ml 툴링 3.11 전제) — ml venv·의존성 구성은 P3-T1 시점에 3.11로 구축(G10 절차)
## STOP 보고 (운영자 확인 대기)
- CHECKPOINT-0: Phase 0 부트스트랩 5태스크 전부 DoD 통과로 완료 — 운영자 검수 대기(하네스 루프 정상 동작 여부 판정)
- ~~[R1/P1-T3] 실검증 패키지 준비 완료 — 운영자 수행 대기...~~ **해소(2026-08-10)**: 스코프 변경으로 R1 검증 불필요. plan.md Phase 1 참조
- [P1-T2] G6 해석 확인 요청(참고용 — P1-T2는 완료·유지 상태, 라이브 캡처 F-C4 재개 시에만 재소집 필요): SCK에는 비디오 캡처 완전 비활성화 속성이 없음(0×0 구성은 -3812 거부, 구성 변형 5종 실측). 에이전트 구현 = 최소 표면(2×2)·커서 없음·최저 프레임 간격 + 비디오 출력(.screen) 미등록 → 비디오 프레임이 프로세스로 전달되는 경로 부재(프로브: videoBuffers=0). 이것이 G6 "비디오 캡처 활성화 금지"를 충족하는지 운영자 판정 필요 — 불인정 시 P1-T2 재설계(대안 경로는 G10·큐 수정 사항)
