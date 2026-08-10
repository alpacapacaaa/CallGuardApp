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
- **다음 태스크 P2-T1**(Preprocess): Phase 1의 에이전트 큐 소진(P1-T2·T4·T5 완료) — G-1은 P1-T3(운영자) 미수행으로 준비 불가, STOP 대기. 큐 규칙 근거 전진: plan.md 리스크 표 "P2·P3는 픽스처 기반이므로 계속 전진" + P2-T1 의존=P0-T3 only(충족) + P4-T1과 달리 G-1 의존 미지정. 운영자가 G-1 대기 정지를 원하면 큐 수정으로 지시
- P2-T1 착수 시: Sources/Preprocess(현재 placeholder)에 48→16kHz 리샘플링·VAD·2s 청크화·타임스탬프 구현. DoD=swift test --filter PreprocessTests(청크 경계 오차 ≤ 50ms 검증 포함). FileAudioSource 48k 합성 픽스처(WavSynth)로 결정적 테스트 가능. 외부 DSP 의존성 추가는 G10 STOP — 직접 구현 원칙(§8-5)
- P1-T1(운영자)·P1-T3(운영자) 대기 — CLI: `.build/debug/CaptureDemo --seconds N --out-dir DIR` (remote.wav·local.wav 생성). P1-T3는 remote.wav 사용
- **CHECKPOINT-0(운영자) 검수 대기** — Phase 0 부트스트랩 완료 상태 유지
- 환경 노트: 로컬 python3는 3.12.8(§4는 ml 툴링 3.11 전제) — ml venv·의존성 구성은 P3-T1 시점에 3.11로 구축(G10 절차)
## STOP 보고 (운영자 확인 대기)
- CHECKPOINT-0: Phase 0 부트스트랩 5태스크 전부 DoD 통과로 완료 — 운영자 검수 대기(하네스 루프 정상 동작 여부 판정)
- [P1-T2] G6 해석 확인 요청: SCK에는 비디오 캡처 완전 비활성화 속성이 없음(0×0 구성은 -3812 거부, 구성 변형 5종 실측). 에이전트 구현 = 최소 표면(2×2)·커서 없음·최저 프레임 간격 + 비디오 출력(.screen) 미등록 → 비디오 프레임이 프로세스로 전달되는 경로 부재(프로브: videoBuffers=0). 이것이 G6 "비디오 캡처 활성화 금지"를 충족하는지 운영자 판정 필요 — 불인정 시 P1-T2 재설계(대안 경로는 G10·큐 수정 사항)
