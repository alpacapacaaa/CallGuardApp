# STATE
## 현재 태스크
P0-T4
## 완료 태스크
- [x] P0-T1 (2026-08-09, commit 7ac9e04)
- [x] P0-T2 (2026-08-10, commit 0ea0725)
- [x] P0-T3 (2026-08-10, commit 1a80fb8)
## 작업 메모 (현재 태스크의 세부 체크리스트)
P0-T3 완료 체크리스트 (기록용):
- [x] VERIFY: git clean, 직전 DoD `./scripts/ci_fast.sh` 재실행 exit 0
- [x] 결정: 모듈 배치 — `AudioTrack`/`AudioChunk`/`AudioSource`/`FileAudioSource`/`WavFile`/`CaptureError` → Capture, `TranscriptSegment` → STT, `RiskScore`/`RiskCategory` → Detection(§4 의존 방향). PRD F-M4 필드 계약 준수(value/category/evidence[], 5종)
- [x] 결정: 페이싱 — ContinuousClock 절대 스케줄, 청크 종료 시점 방출(100ms/청크). WAV 최소 파서 직접 구현(PCM16·float32, 모노 다운믹스), 신규 의존성 없음(G10)
- [x] Sources/Capture 4파일 + Sources/STT/TranscriptSegment.swift + Sources/Detection/RiskScore.swift
- [x] Package.swift: TestSupport 타깃 + 테스트 타깃 의존성(Fast: Capture·Detection, Slow: Capture)
- [x] fast: WavParsingTests 10건(파싱·다운믹스·거부 5종·미존재 파일·트랙 고정) + RiskModelTests 2건(카테고리 5종 고정·evidence 순서) — 14건 통과
- [x] slow: AudioSourceTests — 10s 리플레이 10.062s(9.5–10.5 충족) + 샘플 160,000 무결성 + 청크 100건 + 첫 청크 ≥ 80ms(일괄 방출 차단)
- [x] 포맷·린트 0 위반 (swiftformat wrap 규칙 3파일 자동 적용, swiftlint optional_data_string_conversion 1건 코드 수정으로 해소)
- [x] DoD 실행: `swift test --filter AudioSourceTests` exit 0 → 원문 아래
- [x] 회귀 확인: `./scripts/ci_fast.sh` exit 0 (fast 14건 + 린트)
## 마지막 DoD 실행 결과 (원문)
```
$ swift test --filter AudioSourceTests
Building for debugging...
[0/8] Write sources
[4/8] Write swift-version--58304C5D6DBC2206.txt
[6/12] Compiling TestSupport WavSynth.swift
[7/12] Emitting module TestSupport
[8/12] Emitting module Capture
[9/12] Compiling Capture WavFile.swift
[9/13] Write Objects.LinkFileList
[11/17] Emitting module CallGuardSlowTests
[12/17] Compiling CallGuardSlowTests AudioSourceTests.swift
[12/17] Linking CallGuardApp
[13/17] Applying CallGuardApp
[15/17] Compiling CallGuardFastTests WavParsingTests.swift
[16/17] Emitting module CallGuardFastTests
[16/18] Write Objects.LinkFileList
[17/18] Linking CallGuardPackageTests
Build complete! (1.15s)
Test Suite 'Selected tests' started at 2026-08-10 17:31:16.101.
Test Suite 'CallGuardPackageTests.xctest' started at 2026-08-10 17:31:16.101.
Test Suite 'CallGuardPackageTests.xctest' passed at 2026-08-10 17:31:16.101.
	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.000) seconds
Test Suite 'Selected tests' passed at 2026-08-10 17:31:16.101.
	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
◇ Test run started.
↳ Testing Library Version: 1902
↳ Target Platform: arm64e-apple-macos14.0
◇ Suite AudioSourceTests started.
◇ Test tenSecondReplayTakesRealTime() started.
✔ Test tenSecondReplayTakesRealTime() passed after 10.062 seconds.
✔ Suite AudioSourceTests passed after 10.062 seconds.
✔ Test run with 1 test in 1 suite passed after 10.062 seconds.
exit: 0
```
## 미해결 이슈 / 다음 세션 지시
- P0-T4 진행: 측정 스크립트 스텁 4종 — `scripts/measure_latency.sh`, `scripts/load_test.sh`, `scripts/verify_no_egress.sh`, `ml/eval/run.py`. 미구현 구간은 "NOT_IMPLEMENTED" 명시 출력(조용한 성공 금지), exit code 규약 주석 필수. `ml/eval/`은 plan.md 예정 구조(신규 생성 가능), Python 3.11 전제이나 스텁은 의존성 없이(표준 라이브러리만)
- 주의: 이 스크립트들은 이후 태스크의 DoD·평가 수단이 됨 — 생성 후 G12 적용 대상. 스텁 단계에서 exit code 규약을 주석으로 고정할 것
- FileAudioSource는 100ms 청크·청크 종료 시점 방출로 고정(P0-T3) — P1-T2 SCK 캡처 구현 시 동일 계약(100ms 단위, capturedAt) 맞출 것
## STOP 보고 (운영자 확인 대기)
- (없음)
