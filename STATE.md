# STATE
## 현재 태스크
P1-T5
## 완료 태스크
- [x] P0-T1 (2026-08-09, commit 7ac9e04)
- [x] P0-T2 (2026-08-10, commit 0ea0725)
- [x] P0-T3 (2026-08-10, commit 1a80fb8)
- [x] P0-T4 (2026-08-10, commit 7136418)
- [x] P0-T5 (2026-08-10, commit da8f968)
- [x] P1-T2 (2026-08-10, commit 2508ac6)
- [x] P1-T4 (2026-08-10, commit 7a56f62)
## 작업 메모 (현재 태스크의 세부 체크리스트)
P1-T4 완료 체크리스트:
- [x] VERIFY: git clean, P1-T2 DoD(WavWriterTests) 재실행 6/6 통과
- [x] §9 심볼 검증(SDK 헤더 + typecheck 프로브): AVAudioApplication.shared.recordPermission(.granted/.denied/.undetermined)·requestRecordPermission() async→Bool(macos 14), AVAudioEngine.inputNode·installTap(onBus:bufferSize:format:block:)·floatChannelData 실존 확인. AVAudioEngine.h 명시: input 미가용 시 inputNode 접근은 예외 발생 → 권한 게이트(MicPermission) 선행·포맷 가드 설계
- [x] CaptureError.microphoneDenied 추가 / AudioTrack.captureFileName 파일명 규약(remote.wav·local.wav)
- [x] MicAudioCapture(AudioSource, track=.local): async init(권한→허드웨어 포맷 조회, 48kHz 실측)→tap→모노 다운믹스→ChunkAccumulator 100ms, 탭 스레드는 NSLock 보호(오디오 콜백 경계), deinit 엔진 정지 안전망
- [x] CaptureDemo 통합: --out → --out-dir DIR, 태스크 그룹 듀얼 캡처(파일 수명주기 태스크별 소유), 트랙 태그 불일치 런타임 가드, 종료코드 4(마이크 권한) 추가
- [x] fast 테스트 3건 추가(TrackTaggingTests: 파일명 매핑·태그 방향·청크 태그 보존) — fast 레인 31건 통과
- [x] 실캡처 증빙(운영자 스모크 대행): 세션 1회 exit 0 → remote.wav·local.wav 2파일 각 3.9s@48kHz(afinfo "1 ch, 48000 Hz, Int16") / TTS 재생 중 캡처: remote peak 20326·RMS 3739 vs local peak 3179·RMS 608 — 신호 경로별 분리 확인(직접 경로 vs 음향 픽업)
- [x] swiftformat·swiftlint 0 위반, ./scripts/ci_fast.sh exit 0
## 마지막 DoD 실행 결과 (원문)
```
$ swift test --filter TrackTaggingTests
✔ Test sourceTrackTagsMatchPipelineDirection() passed after 0.001 seconds.
✔ Test captureFileNamesAreFixedPerTrack() passed after 0.001 seconds.
✔ Test accumulatorTagsChunksWithItsTrack() passed after 0.001 seconds.
✔ Suite TrackTaggingTests passed after 0.001 seconds.
✔ Test run with 3 tests in 1 suite passed after 0.001 seconds.

$ .build/debug/CaptureDemo --seconds 4 --out-dir /tmp/p1t4-session
완료: [local] 3.9s (187200프레임 @ 48000Hz) → /tmp/p1t4-session/local.wav
완료: [remote] 3.9s (187200프레임 @ 48000Hz) → /tmp/p1t4-session/remote.wav
exit: 0   (세션 1회 → 2파일, afinfo "1 ch, 48000 Hz, Int16" 양쪽 확인)

$ ./scripts/ci_fast.sh
==> ci_fast: 전 단계 통과
exit: 0   (빌드 + fast 레인 31건 + swiftlint 0 위반 + swiftformat 0/31)
```
## 미해결 이슈 / 다음 세션 지시
- **다음 태스크 P1-T5 [병렬 가능]**(권한 흐름 조사): docs/permissions.md 작성(TCC 화면녹화·마이크 요청 경로, 거부 시 동작 — P1-T4에서 이미 구현된 종료코드 3·4 안내 흐름 포함) + "권한 미보유 시 크래시 없이 안내 상태 진입" 테스트. 난점: TCC 상태를 테스트에서 결정적으로 조작 불가 — 가능한 검증 범위(예: MicPermission 분기 로직·report() 종료코드 매핑 단위 테스트)를 먼저 조사하고, 불가 부분은 문서로 증빙 대체. P1-T2 STOP 보고(G6)·CHECKPOINT-0 판정 선행 여부 운영자 확인
- P1-T1(운영자)·P1-T3(운영자) 대기 — CLI 인터페이스 변경 주의: `--out PATH` 삭제, **`--seconds N --out-dir DIR`** (DIR 아래 remote.wav·local.wav 생성). P1-T3는 remote.wav 사용
- **CHECKPOINT-0(운영자) 검수 대기** — Phase 0 부트스트랩 완료 상태 유지
- 환경 노트: 로컬 python3는 3.12.8(§4는 ml 툴링 3.11 전제) — ml venv·의존성 구성은 P3-T1 시점에 3.11로 구축(G10 절차)
## STOP 보고 (운영자 확인 대기)
- CHECKPOINT-0: Phase 0 부트스트랩 5태스크 전부 DoD 통과로 완료 — 운영자 검수 대기(하네스 루프 정상 동작 여부 판정)
- [P1-T2] G6 해석 확인 요청: SCK에는 비디오 캡처 완전 비활성화 속성이 없음(0×0 구성은 -3812 거부, 구성 변형 5종 실측). 에이전트 구현 = 최소 표면(2×2)·커서 없음·최저 프레임 간격 + 비디오 출력(.screen) 미등록 → 비디오 프레임이 프로세스로 전달되는 경로 부재(프로브: videoBuffers=0). 이것이 G6 "비디오 캡처 활성화 금지"를 충족하는지 운영자 판정 필요 — 불인정 시 P1-T2 재설계(대안 경로는 G10·큐 수정 사항)
