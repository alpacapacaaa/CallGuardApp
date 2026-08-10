# STATE
## 현재 태스크
P1-T4
## 완료 태스크
- [x] P0-T1 (2026-08-09, commit 7ac9e04)
- [x] P0-T2 (2026-08-10, commit 0ea0725)
- [x] P0-T3 (2026-08-10, commit 1a80fb8)
- [x] P0-T4 (2026-08-10, commit 7136418)
- [x] P0-T5 (2026-08-10, commit da8f968)
- [x] P1-T2 (2026-08-10, commit 2508ac6)
## 작업 메모 (현재 태스크의 세부 체크리스트)
P1-T2 완료 체크리스트:
- [x] VERIFY: git clean, P0-T5 DoD 재실행 통과(wav 10개 + MANIFEST_OK)
- [x] §9 심볼 검증(SDK 헤더 grep + swiftc -typecheck 프로브): capturesAudio·sampleRate·channelCount·SCContentFilter(display:excludingWindows:)·addStreamOutput(_:type:sampleHandlerQueue:)·startCapture/stopCapture·SCStreamErrorDomain/SCStreamError.userDeclined(-3801) 실존 확인. 함정 3건 실증: ① SCDisplay에 isMain 없음 → CGMainDisplayID() 매칭 ② capturesVideo 속성 없음 ③ width=height=0 구성은 -3812(InvalidParameter)로 거부 → 최소 표면 2×2 + 비디오 출력 미등록이 오디오 전용 구성(G6, STOP 보고 참조)
- [x] CaptureError 확장: screenCaptureDenied / captureFailed(detail:) / wavWriteFailed(path:)
- [x] WavWriter(Sources/Capture): PCM16 모노, 44B 헤더, close() 시 RIFF·data 크기 확정, float→Int16 클립 — 버그 1건 수정(FileHandle 기본 오프셋 0 → seekToEnd 필수, 테스트가 검출)
- [x] ChunkAccumulator(Sources/Capture): 임의 크기 입력 → FileAudioSource.chunkDuration(100ms) AudioChunk 계약 일치, 잔여분 flush
- [x] SystemAudioEngine + SystemAudioCapture(AudioSource, track=.remote, 48kHz): SCK 오디오 전용 스트림, CMSampleBuffer→모노 float 디코딩(Float32·Int16), 단절·권한거부 → typed error
- [x] Package.swift: executableTarget CaptureDemo (Capture 의존)
- [x] CaptureDemo CLI: --seconds·--out, SIGINT 조기 종료, 권한 미부여 시 안내 후 종료코드 3, G1-safe 출력
- [x] fast 테스트 11건 추가(WavWriter 6 = DoD 자동 판정, ChunkAccumulator 4, 계약 1) — fast 레인 28건 통과
- [x] 실캡처 검증(에이전트 대리로 운영자 스모크 대체 증빙): 무음 캡처 exit 0 + afinfo "1 ch, 48000 Hz, Int16" / TTS 음성 재생 중 3s 캡처 → peak 24573·RMS 4022(비침묵) 확인
- [x] swiftformat·swiftlint 0 위반, ./scripts/ci_fast.sh exit 0
## 마지막 DoD 실행 결과 (원문)
```
$ swift test --filter WavWriterTests
✔ Test rejectsMissingDirectory() passed after 0.001 seconds.
✔ Test appendAfterCloseFails() passed after 0.001 seconds.
✔ Test writesValidPcm16MonoHeader() passed after 0.001 seconds.
✔ Test clipsOutOfRangeSamples() passed after 0.001 seconds.
✔ Test accumulatesAcrossAppends() passed after 0.001 seconds.
✔ Test roundTripsThroughWavFile() passed after 0.002 seconds.
✔ Suite WavWriterTests passed after 0.002 seconds.
✔ Test run with 6 tests in 1 suite passed after 0.002 seconds.

$ ./scripts/ci_fast.sh
==> ci_fast: 전 단계 통과
exit: 0   (빌드 + fast 레인 28건 + swiftlint 0 위반 + swiftformat 0/29)
```
보조 확인(참고): `$ CaptureDemo --seconds 3` 실행 exit 0 → afinfo "Data format: 1 ch, 48000 Hz, Int16 / estimated duration: 2.9 sec"
DoD 운영자 항목("음악 재생 중 CLI 실행 → 재생 확인")은 최종 음악 스모크 대기 — 에이전트는 TTS 합성 음성으로 비침묵 캡처까지 증빙(작업 메모 참조)
## 미해결 이슈 / 다음 세션 지시
- **다음 태스크 P1-T4**(마이크 트랙 캡처): P1-T3(운영자, P1-T1 선행 대기)은 에이전트 수행 불가이므로 큐 규칙상 건너뜀. P1-T4 착수 시: AVAudioEngine input tap → local.wav, 동일 CaptureDemo에 통합(세션 1회에 remote.wav/local.wav 2파일), 트랙 태깅 테스트. 마이크 TCC 권한 미부여 시에도 크래시 없이 안내(종료코드 체계 재사용). 청크 계약(100ms·capturedAt) 유지
- **CHECKPOINT-0(운영자) 검수 대기** — Phase 0 부트스트랩 완료 상태 유지
- P1-T1(운영자, 실기기 Continuity 환경 구축)·P1-T3(운영자, R1 실통화 캡처 검증) 대기 — P1-T2 CLI 사용: `.build/debug/CaptureDemo --seconds N --out remote.wav`
- P1-T2 운영자 최종 스모크(음악 재생 → 재생 확인) 미수행 — 위 지시대로 실행 후 docs/spike-r1-report.md 준비 시 활용
- 환경 노트: 로컬 python3는 3.12.8(§4는 ml 툴링 3.11 전제) — ml venv·의존성 구성은 P3-T1 시점에 3.11로 구축(G10 절차)
## STOP 보고 (운영자 확인 대기)
- CHECKPOINT-0: Phase 0 부트스트랩 5태스크 전부 DoD 통과로 완료 — 운영자 검수 대기(하네스 루프 정상 동작 여부 판정)
- [P1-T2] G6 해석 확인 요청: SCK에는 비디오 캡처 완전 비활성화 속성이 없음(0×0 구성은 -3812 거부, 구성 변형 5종 실측). 에이전트 구현 = 최소 표면(2×2)·커서 없음·최저 프레임 간격 + 비디오 출력(.screen) 미등록 → 비디오 프레임이 프로세스로 전달되는 경로 부재(프로브: videoBuffers=0). 이것이 G6 "비디오 캡처 활성화 금지"를 충족하는지 운영자 판정 필요 — 불인정 시 P1-T2 재설계(대안 경로는 G10·큐 수정 사항)
