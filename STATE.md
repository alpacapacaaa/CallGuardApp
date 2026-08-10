# STATE
## 현재 태스크
P4-T4(부분 — 폐기 검증만 남음)
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
- [x] P3-T2 (2026-08-10, commit c01101e — P2-T2가 G10(외부 의존성) 승인 대기라 [병렬 가능] 경로로 전진)
- [x] P4-T1 (2026-08-11, 커밋 예정 — F-M8 동의 게이트를 SessionController 리듀서에 구조적으로 포함, P4-T4 선반영)
## 작업 메모 (현재 태스크의 세부 체크리스트)
P4-T1 완료 + P4-T4 착수 메모:
- [x] 설계: SessionController(순수 리듀서) — consentGranted/sourceStarted/sourceEnded/manualStopRequested 4개 이벤트, idle→active→ended(endOfStream|manualStop) 전이. sourceStarted는 hasConsent==true일 때만 idle→active 허용 — G7 "동의 전 파이프라인 시작 코드 경로 금지"를 타입 수준에서 강제(런타임 체크가 아니라 리듀서의 match arm 자체가 불가능한 경로를 만들지 않음)
- [x] Sources/Session/{SessionState,SessionController}.swift, Tests/CallGuardFastTests/SessionControllerTests.swift 10건(동의 전 무시·동의 후 전이·EOF·수동중지·종료 후 이벤트 무시·중복 시작·전체 라이프사이클)
- [x] Package.swift: CallGuardFastTests에 Session 의존성 추가
- [ ] **P4-T4 잔여 — F-M7 폐기 검증**: 세션 종료 후 임시 파일 0건 fast 테스트. GRDB 불필요(기본값=무저장 자체를 검증하는 것이므로) — 다음 세션에서 바로 착수 가능
- [ ] **P4-T4 잔여 — 옵트인 저장**: "옵트인 DB에 평문 전사 미검출" 테스트는 실제 암호화 DB가 있어야 검증 가능. AGENTS.md 확정 스택은 GRDB(SQLite)지만 **신규 SwiftPM 의존성 추가는 그 자체로 G10 대상** — 운영자 승인 전 착수 금지. P2-T2(whisper.cpp)와 함께 승인 대기 중
## 이전 작업 메모(P3-T2 완료 체크리스트, 보존)
- [x] 설계: RuleSet(고정 스키마 전용 최소 YAML 파서, 직접 구현) + RuleSignature(CryptoKit SHA256 — 시스템 프레임워크라 G10 비대상) + RuleEngine(load 시 서명 검증, evaluate 키워드 매칭)
- [x] rules.yaml(저장소 루트, 카테고리 5종 각 5개 키워드) + rules.yaml.sig(SHA256 hex) 작성
- [x] Sources/Detection/{RuleSet,RuleSignature,RuleEngine}.swift 구현
- [x] Tests/CallGuardFastTests/RuleEngineTests.swift 12건: 5카테고리 로드 검증, 서명 불일치 거부, 카테고리별 양성 1+음성 1(총 10건) — 실제 rules.yaml/.sig를 #filePath로 직접 로드(픽스처 드리프트 방지)
- [x] scripts/check_rule_coverage.sh: rules.yaml 룰 ID 전부가 테스트 파일에서 문자열로 참조되는지 grep 검사, exit 0/1 규약. macOS BSD grep은 `\s` 미지원 — `[[:space:]]`로 수정
- [x] swiftlint 0 위반(순환복잡도·함수 길이 위반 2건 → Builder 구조체로 분리해 해소), swiftformat 0/42(hoistTry·docComments 등 4건 자동 수정)
## 마지막 DoD 실행 결과 (원문)
```
$ swift test --filter SessionControllerTests
◇ Suite SessionControllerTests started.
✔ Test startsIdle() passed after 0.001 seconds.
✔ Test sourceStartedWithoutConsentIsIgnored() passed after 0.001 seconds.
✔ Test consentGrantedThenSourceStartedTransitionsToActive() passed after 0.001 seconds.
✔ Test sourceEndedTransitionsActiveToEndedOfStream() passed after 0.001 seconds.
✔ Test manualStopTransitionsActiveToEndedManualStop() passed after 0.001 seconds.
✔ Test sourceEndedWhileIdleIsIgnored() passed after 0.001 seconds.
✔ Test manualStopWhileIdleIsIgnored() passed after 0.001 seconds.
✔ Test eventsAfterEndedAreIgnored() passed after 0.001 seconds.
✔ Test duplicateSourceStartedWhileActiveStaysActive() passed after 0.001 seconds.
✔ Test fullPlaybackLifecycleSequence() passed after 0.001 seconds.
✔ Test run with 10 tests in 1 suite passed after 0.001 seconds.

$ ./scripts/ci_fast.sh
==> ci_fast: 전 단계 통과 (0/45 files require formatting, swiftlint 0 위반)
```
P2-T1·P3-T2 DoD 원문은 이 문서의 이전 리비전(git log STATE.md 이력 참조).
## 미해결 이슈 / 다음 세션 지시
- **운영자 지시(2026-08-10): 스코프 축소 — ① 파일 재생(FileAudioSource) 입력 확정, 라이브 캡처는 Could(F-C4) ② 2차 분류기 경량 선형 분류기로 대체.** 상세는 PRD.md §2/F-M1/F-M2/F-M4/§6(R1)/§7, plan.md Phase 1(보류)·P3-T3/T4·P4-T1, AGENTS.md §4에 반영 완료.
- **Must 우선 스코프 결정(운영자 승인, 유효)**: 시연 가능 버전까지 Must(F-M1~F-M8) 임계경로 우선.
- **완료 요약**: P2-T1(Preprocess) · P3-T2(RuleEngine, P2-T2 G10 대기라 병렬 경로) · P4-T1(SessionController + F-M8 동의 게이트 선반영) — 전부 DoD 통과, 커밋 완료.
- **G10 승인 대기 2건(운영자 결정 필요, 병합 요청)**:
  1. **P2-T2 whisper.cpp**: 설치 방식(git submodule+소스 빌드 / 사전빌드 XCFramework / SwiftPM 패키지) 결정 필요. 모델은 P2-T6에서 base/small 확정 예정이라 우선 base로 임시 착수 가능.
  2. **P4-T4 옵트인 저장(GRDB)**: AGENTS.md 확정 스택이지만 신규 SwiftPM 의존성 추가 자체가 G10 대상. "옵트인 DB에 평문 전사 미검출" 테스트가 실제 DB 없이는 불가능.
  둘 다 미승인 상태면 에이전트는 임의 착수하지 않는다(§3-2). 승인 시 lockfile 갱신 동반.
- **다음 태스크 후보(G10 무관, 바로 착수 가능)**: P4-T4의 F-M7(폐기) 서브파트 — "세션 종료 후 임시 파일 0건" fast 테스트. 기본값=무저장 자체를 검증하는 것이라 GRDB 불필요. 이후 P3-T1(평가셋, 운영자의 금감원 데이터 이용조건 확인 필요해 부분 블록)도 로더 코드 부분은 착수 가능.
- 엔진 노트(2026-08-10~11): Claude Code Pro 구독 세션으로 P2-T1·P3-T2·P4-T1 세 태스크 연속 실행 — Qwen 하네스에서 첫 전환. 실측: 세 태스크(총 8개 신규 Swift 파일, 테스트 30건, rules.yaml+서명, 커버리지 스크립트, 린트 위반 다수 수정) CI 전체 통과까지 5시간 창의 극히 일부만 소요. G10 승인이 필요한 두 건을 빼면 병목은 토큰/시간이 아니라 운영자 결정 대기로 이동한 상태.
- **CHECKPOINT-0(운영자) 검수 대기** — Phase 0 부트스트랩 완료 상태 유지
- 환경 노트: 로컬 python3는 3.12.8(§4는 ml 툴링 3.11 전제) — ml venv·의존성 구성은 P3-T1 시점에 3.11로 구축(G10 절차)
## STOP 보고 (운영자 확인 대기)
- CHECKPOINT-0: Phase 0 부트스트랩 5태스크 전부 DoD 통과로 완료 — 운영자 검수 대기(하네스 루프 정상 동작 여부 판정)
- ~~[R1/P1-T3] 실검증 패키지 준비 완료 — 운영자 수행 대기...~~ **해소(2026-08-10)**: 스코프 변경으로 R1 검증 불필요. plan.md Phase 1 참조
- [P1-T2] G6 해석 확인 요청(참고용 — P1-T2는 완료·유지 상태, 라이브 캡처 F-C4 재개 시에만 재소집 필요): SCK에는 비디오 캡처 완전 비활성화 속성이 없음(0×0 구성은 -3812 거부, 구성 변형 5종 실측). 에이전트 구현 = 최소 표면(2×2)·커서 없음·최저 프레임 간격 + 비디오 출력(.screen) 미등록 → 비디오 프레임이 프로세스로 전달되는 경로 부재(프로브: videoBuffers=0). 이것이 G6 "비디오 캡처 활성화 금지"를 충족하는지 운영자 판정 필요 — 불인정 시 P1-T2 재설계(대안 경로는 G10·큐 수정 사항)
