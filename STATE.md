# STATE
## 현재 태스크
P2-T1
## 완료 태스크
- [x] P0-T1 (2026-08-09, commit 7ac9e04)
- [x] P0-T2 (2026-08-10, commit 0ea0725)
- [x] P0-T3 (2026-08-10, commit 1a80fb8)
- [x] P0-T4 (2026-08-10, commit 7136418)
- [x] P0-T5 (2026-08-10, commit da8f968)
- [x] P1-T2 (2026-08-10, commit 2508ac6)
- [x] P1-T4 (2026-08-10, commit 7a56f62)
- [x] P1-T5 (2026-08-10, commit 8e594c3)
## 작업 메모 (현재 태스크의 세부 체크리스트)
P1-T5 완료 체크리스트:
- [x] VERIFY: git clean, P1-T4 DoD(TrackTaggingTests) 재실행 3/3 통과
- [x] 설계: 권한 거부→안내 매핑이 CaptureDemo(실행 타깃)에 있어 fast 레인 테스트 불가 → Capture 모듈 PermissionGuidance로 추출. docs/는 plan.md DoD가 요구하는 문서 디렉토리(§4의 소스 아키텍처 신규 디렉토리가 아님) — 생성
- [x] Sources/Capture/PermissionGuidance.swift: 순수 총함수 매핑(screenCaptureDenied→exit 3 / microphoneDenied→exit 4 / 그 외 nil)
- [x] CaptureDemo.report() PermissionGuidance 경유 전환(중복 안내 문자 제거)
- [x] PermissionGuidanceTests 5건: 권한 2종 안내 상태·종료코드 구분·비권한 오류 nil·전 케이스 크래시 없음 — fast 레인 36건 통과
- [x] docs/permissions.md(95줄): 요청 경로(SCK=SCShareableContent 최초 호출, 마이크=AVAudioApplication.recordPermission→requestRecordPermission), 거부 동작, 크래시 없음 근거(마이크=inputNode 무접근 선행 게이트·화면=throw 포착→typed error), 권한 주체(터미널 귀속), tccutil 재시험 절차, 검증 범위·한계 명시
- [x] swiftformat·swiftlint 0 위반, ./scripts/ci_fast.sh exit 0
## 마지막 DoD 실행 결과 (원문)
```
$ test -f docs/permissions.md && echo 존재
존재   (95줄)

$ swift test --filter PermissionGuidanceTests
✔ Test nonPermissionErrorsAreNotGuidance() passed after 0.001 seconds.
✔ Test screenCaptureDeniedMapsToGuidanceExit3() passed after 0.001 seconds.
✔ Test mappingIsTotalOverAllErrorCases() passed after 0.001 seconds.
✔ Test permissionExitCodesAreDistinct() passed after 0.001 seconds.
✔ Test microphoneDeniedMapsToGuidanceExit4() passed after 0.001 seconds.
✔ Suite PermissionGuidanceTests passed after 0.001 seconds.
✔ Test run with 5 tests in 1 suite passed after 0.001 seconds.

$ ./scripts/ci_fast.sh
==> ci_fast: 전 단계 통과
exit: 0   (빌드 + fast 레인 36건 + swiftlint 0 위반 + swiftformat 0/33)
```
한계 명시(docs §6): 실제 프롬프트·거부 실기기 재현은 운영자 항목(tccutil 리셋 절차 문서화) — fast 레인은 매핑 총함수성 검증
## 미해결 이슈 / 다음 세션 지시
- **운영자 지시(2026-08-10): 가속 방향 = ① R1 실검증 지금 준비 ② Must만 데모 우선.** 아래 두 항목 이 지시의 산출
- **R1 턴키 패키지 준비 완료(에이전트)**: `docs/env-checklist.md`(P1-T1 수행 체크리스트) + `docs/spike-r1-report.md`(P1-T3 재현절차·증빙·판정 템플릿, G5/G1-safe 메타만 기록). 남은 수행·판정은 운영자: env-checklist 전 항목 `[x]` → `CaptureDemo --seconds 20 --out-dir /tmp/r1` 실행 → remote.wav 청취 판정 → 리포트 1절 Go/No-Go 기록. 완료 시 G-1 게이트 판정 재료 충족
- **Must 우선 스코프 결정(운영자 승인)**: 시연 가능 버전까지 Must(F-M1~F-M8) 임계경로 우선 전진, Should(F-S1·S2·S3·S5·S6)·Could는 후순위 유보. 큐 자체 수정은 운영자 권한 — 에이전트는 태스크 선택 시 Must 임계경로(P2-T1→T2→T3→…→P4 경고 UI·동의 게이트)를 우선하는 것으로 반영
- **다음 태스크 P2-T1**(Preprocess): Phase 1의 에이전트 큐 소진(P1-T2·T4·T5 완료) — G-1은 P1-T3(운영자) 미수행으로 준비 불가, STOP 대기. 큐 규칙 근거 전진: plan.md 리스크 표 "P2·P3는 픽스처 기반이므로 계속 전진" + P2-T1 의존=P0-T3 only(충족) + P4-T1과 달리 G-1 의존 미지정. R1 운영자 수행과 병렬로 전진
- P2-T1 착수 시: Sources/Preprocess(현재 placeholder)에 48→16kHz 리샘플링·VAD·2s 청크화·타임스탬프 구현. DoD=swift test --filter PreprocessTests(청크 경계 오차 ≤ 50ms 검증 포함). FileAudioSource 48k 합성 픽스처(WavSynth)로 결정적 테스트 가능. 외부 DSP 의존성 추가는 G10 STOP — 직접 구현 원칙(§8-5)
- **CHECKPOINT-0(운영자) 검수 대기** — Phase 0 부트스트랩 완료 상태 유지
- 환경 노트: 로컬 python3는 3.12.8(§4는 ml 툴링 3.11 전제) — ml venv·의존성 구성은 P3-T1 시점에 3.11로 구축(G10 절차)
## STOP 보고 (운영자 확인 대기)
- CHECKPOINT-0: Phase 0 부트스트랩 5태스크 전부 DoD 통과로 완료 — 운영자 검수 대기(하네스 루프 정상 동작 여부 판정)
- [R1/P1-T3] 실검증 패키지 준비 완료 — 운영자 수행 대기. 순서: ① docs/env-checklist.md 전 항목 [x] ② 통화 연결 후 `.build/debug/CaptureDemo --seconds 20 --out-dir /tmp/r1` ③ /tmp/r1/remote.wav 청취 → docs/spike-r1-report.md 1절 Go/No-Go 기록. 이것이 G-1 게이트 판정 재료이며 프로젝트 임계경로. No-Go 시에도 에이전트는 폴백 임의 착수 금지(§3)
- [P1-T2] G6 해석 확인 요청: SCK에는 비디오 캡처 완전 비활성화 속성이 없음(0×0 구성은 -3812 거부, 구성 변형 5종 실측). 에이전트 구현 = 최소 표면(2×2)·커서 없음·최저 프레임 간격 + 비디오 출력(.screen) 미등록 → 비디오 프레임이 프로세스로 전달되는 경로 부재(프로브: videoBuffers=0). 이것이 G6 "비디오 캡처 활성화 금지"를 충족하는지 운영자 판정 필요 — 불인정 시 P1-T2 재설계(대안 경로는 G10·큐 수정 사항)
