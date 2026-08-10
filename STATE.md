# STATE
## 현재 태스크
P0-T3
## 완료 태스크
- [x] P0-T1 (2026-08-09, commit 7ac9e04)
- [x] P0-T2 (2026-08-10, commit 0ea0725)
## 작업 메모 (현재 태스크의 세부 체크리스트)
P0-T2 완료 체크리스트 (기록용):
- [x] VERIFY: P0-T1 DoD 재실행 통과 — swift build exit 0 / swiftlint 위반 0 / STATE.md 존재 (swift 6.3.3, 도구 brew 경로 확인)
- [x] 실증(/tmp 스크래치): Swift Testing은 tools-version 5.10에서 컴파일·발견되나, swift test CLI는 태그 필터 미지원 — `--filter`는 이름 정규식만 매칭(태그만 달린 테스트는 필터에 걸리지 않음 확인)
- [x] 결정: 레인 = 테스트 타깃. `CallGuardFastTests`(단위·룰·정책) / `CallGuardSlowTests`(STT 통합·E2E·부하·벽시계 페이싱). 클래스명은 `<Feature>Tests` 유지(후속 `--filter AudioSourceTests` 등 DoD 호환). Tests/·scripts/는 plan.md가 예정한 최상위 디렉터리(신규 생성 승인 — 직전 세션 지시)
- [x] Package.swift: testTarget 2종 추가
- [x] Tests/CallGuardFastTests/HarnessLayoutTests.swift — 필수 문서(AGENTS/STATE/plan/PRD) 존재 + scripts/ci_fast.sh 존재·실행 비트 검증
- [x] Tests/CallGuardSlowTests/PacingBaselineTests.swift — 1s 수면 후 경과 ≥ 950ms 검증 (P0-T3 실시간 페이싱의 측정 기준선; 벽시계 선도 금지)
- [x] scripts/ci_fast.sh — build → `swift test --filter '^CallGuardFastTests\.'` → swiftlint --strict + swiftformat --lint, 도구 미설치 시 명시 실패 + chmod +x (100755)
- [x] 포맷·린트 0 위반 확인 (swiftformat 0/12, swiftlint 0건 — swiftformat `redundantSwiftTestingSuite` 규칙 발견 → 인자 없는 @Suite 제거)
- [x] 레인 분리 실증: fast 필터는 fast 타깃 2건만, slow 필터는 slow 타깃 1건(1.001s)만 실행
- [x] DoD 실행: `./scripts/ci_fast.sh` exit 0 → 원문 아래
## 마지막 DoD 실행 결과 (원문)
```
$ ./scripts/ci_fast.sh
==> [1/3] swift build
[0/1] Planning build
Building for debugging...
[0/3] Write swift-version--58304C5D6DBC2206.txt
Build complete! (0.13s)
==> [2/3] fast 레인 테스트
[0/1] Planning build
Building for debugging...
[0/4] Write swift-version--58304C5D6DBC2206.txt
Build complete! (0.13s)
Test Suite 'Selected tests' started at 2026-08-10 17:15:15.653.
Test Suite 'CallGuardPackageTests.xctest' started at 2026-08-10 17:15:15.653.
Test Suite 'CallGuardPackageTests.xctest' passed at 2026-08-10 17:15:15.653.
	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Suite 'Selected tests' passed at 2026-08-10 17:15:15.653.
	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
◇ Test run started.
↳ Testing Library Version: 1902
↳ Target Platform: arm64e-apple-macos14.0
◇ Suite HarnessLayoutTests started.
◇ Test ciFastScriptIsExecutable() started.
◇ Test harnessDocumentsExist() started.
✔ Test ciFastScriptIsExecutable() passed after 0.001 seconds.
✔ Test harnessDocumentsExist() passed after 0.001 seconds.
✔ Suite HarnessLayoutTests passed after 0.001 seconds.
✔ Test run with 2 tests in 1 suite passed after 0.001 seconds.
==> [3/3] 린트 (swiftlint --strict, swiftformat --lint)
Linting Swift files in current working directory
Linting 'Detection.swift' (2/12)
Linting 'PacingBaselineTests.swift' (1/12)
Linting 'HarnessLayoutTests.swift' (7/12)
Linting 'Preprocess.swift' (4/12)
Linting 'Capture.swift' (3/12)
Linting 'SessionStore.swift' (5/12)
Linting 'AlertPolicy.swift' (9/12)
Linting 'CallGuardApp.swift' (6/12)
Linting 'CallGuardUI.swift' (8/12)
Linting 'Package.swift' (10/12)
Linting 'STT.swift' (11/12)
Linting 'Session.swift' (12/12)
Done linting! Found 0 violations, 0 serious in 12 files.
Running SwiftFormat...
(lint mode - no files will be changed.)
Reading config file at /Users/bagseon-ung/VoicePishing/.swiftformat
SwiftFormat completed in 0s.
0/12 files require formatting, 4 files skipped.
==> ci_fast: 전 단계 통과
exit: 0
```
## 미해결 이슈 / 다음 세션 지시
- P0-T3 착수 시: `AudioSource` 프로토콜·`FileAudioSource`(벽시계 실시간 페이싱)·`AudioChunk`/`TranscriptSegment`/`RiskScore` 정의. 모듈 소속 먼저 결정(데이터 흐름상 Capture 또는 Session 후보). 테스트 클래스명은 DoD대로 `AudioSourceTests` — 페이싱 검증(10s 리플레이가 9.5–10.5s 소요)은 벽시계 소요이므로 **CallGuardSlowTests** 타깃 소속. 단, 페이싱을 제외한 순수 타입·청크 계산 검증은 CallGuardFastTests에 배치
- 관례 확정: swift test CLI에 태그 필터 없음 → 레인 분리는 타깃으로만(`--filter '^CallGuardFastTests\.'`, `--filter '^CallGuardSlowTests\.'`). swiftformat `redundantSwiftTestingSuite` 규칙 활성 — 인자 없는 `@Suite` 금지(그냥 struct)
- swiftlint/swiftformat은 brew 설치분 — ci_fast.sh가 존재 검사 후 명시 실패하므로 PATH 없는 환경에서 조용히 통과하지 않음
## STOP 보고 (운영자 확인 대기)
- (없음)
