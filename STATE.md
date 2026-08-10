# STATE
## 현재 태스크
P2-T2
## 완료 태스크
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
- [x] P4-T4 (2026-08-11, 커밋 예정 — GRDB 운영자 승인(2026-08-11) 후 착수, 3개 DoD 테스트 전부 통과)
## 작업 메모 (현재 태스크의 세부 체크리스트)
P4-T4 완료 체크리스트:
- [x] G10 승인 반영: Package.swift에 groue/GRDB.swift 의존성 추가(`from: "6.0.0"`), Package.resolved 커밋 대상 포함
- [x] 설계: SessionStore(GRDB, journal_mode=DELETE로 WAL 평문 잔존 경로 제거) + CryptoKit AES-GCM 필드 암호화(전사만 암호화, id·createdAt은 평문 — AGENTS.md §4 "GRDB + 필드 암호화" 그대로) + OptInSessionRecord(메모리 전용 평문 운반체) + SessionStoreError
- [x] Sources/SessionStore/{SessionStore,OptInSessionRecord,SessionStoreError}.swift
- [x] Tests/CallGuardFastTests/SessionStoreTests.swift 4건: 저장·조회 라운드트립, 미존재 ID, **옵트인 DB 파일 원본 바이트에서 평문 미검출(Data.range(of:)로 직접 검사, GRDB 우회)**, 복호화 정상 동작 동시 검증
- [x] F-M7 폐기 검증: noFilesRemainWithoutOptInSave 테스트 — SessionController가 consentGranted→sourceStarted→sourceEnded로 세션을 끝내도 SessionStore.save()를 호출하지 않으면 임시 디렉터리에 파일 0건(기본값=무저장을 아키텍처로 증명)
- [x] P4-T4의 3번째 DoD 항목("동의 전 파이프라인 시작 불가")은 P4-T1의 sourceStartedWithoutConsentIsIgnored로 이미 충족 — 중복 구현 안 함
- [x] swiftlint 0 위반(`db` 식별자 3자 미만 4건 → `database`로 수정, Data→String 변환 경고 2건 → String(bytes:encoding:)/Data.range(of:)로 수정), swiftformat 0/48
## 마지막 DoD 실행 결과 (원문)
```
$ swift test --filter "SessionControllerTests|SessionStoreTests"
◇ Suite SessionControllerTests started.
✔ (10개 전부 통과, P4-T1 커밋 참조)
◇ Suite SessionStoreTests started.
✔ Test noFilesRemainWithoutOptInSave() passed after 0.001 seconds.
✔ Test fetchOfMissingIDReturnsNil() passed after 0.002 seconds.
✔ Test savesAndFetchesRoundTrip() passed after 0.003 seconds.
✔ Test optInDatabaseFileNeverContainsPlaintextTranscript() passed after 0.003 seconds.
✔ Test run with 14 tests in 2 suites passed after 0.003 seconds.

$ ./scripts/ci_fast.sh
==> ci_fast: 전 단계 통과 (0/48 files require formatting, swiftlint 0 위반)
```
## 미해결 이슈 / 다음 세션 지시
- **운영자 지시(2026-08-10): 스코프 축소** — 파일 재생 입력 + 경량 분류기. PRD.md/plan.md/AGENTS.md 반영 완료(git log 참조).
- **Must 우선 스코프 결정(운영자 승인, 유효)**: 시연 가능 버전까지 Must(F-M1~F-M8) 임계경로 우선.
- **G10 승인(2026-08-11, 운영자)**: whisper.cpp·GRDB 둘 다 승인됨. GRDB는 P4-T4에 반영 완료. **whisper.cpp(P2-T2)는 아직 미착수** — 다음 태스크.
- **다음 태스크 P2-T2**(whisper.cpp 통합): Metal 빌드·SwiftPM 래핑·모델 파일 SHA256 고정·검증 로직. 승인된 방식: ggml-org/whisper.cpp 공식 SwiftPM 패키지를 Package.swift 의존성으로 추가(별도 빌드 스크립트·XCFramework 관리 불필요). 모델은 P2-T6에서 base/small 벤치마크 확정 예정이라 우선 base(ggml-base.bin 등)로 임시 착수. DoD: 단발 추론 테스트 통과 + 해시 불일치 시 로드 거부 테스트 통과. **주의**: 모델 파일(수십~수백MB)은 저장소에 커밋 금지(G5·.gitignore 확인), 실행 시 다운로드 경로·SHA256 고정값을 코드/문서에 명시
- **다음 다음 태스크 후보**: P3-T1(평가셋) 로더 코드 부분(운영자의 금감원 데이터 이용조건 확인은 별도), 또는 P2-T2 완료 후 P2-T3(트랙별 스트리밍 STT, P2-T1+P2-T2+P0-T5 의존 — P2-T2 완료 시 충족)
- 엔진 노트(2026-08-10~11): Claude Code Pro 구독 세션으로 P2-T1·P3-T2·P4-T1·P4-T4 네 태스크 연속 실행 — Qwen 하네스에서 첫 전환. 실측: 5시간 창의 일부만 소요, GRDB 신규 의존성 추가(첫 `swift build`가 GRDB 174개 파일 컴파일, ~21초)도 무리 없음. whisper.cpp는 상대적으로 더 무거운 태스크(모델 다운로드+Metal 빌드)라 다음 세션에서 페이스 재확인 필요.
- **CHECKPOINT-0(운영자) 검수 대기** — Phase 0 부트스트랩 완료 상태 유지
- 환경 노트: 로컬 python3는 3.12.8(§4는 ml 툴링 3.11 전제) — ml venv·의존성 구성은 P3-T1 시점에 3.11로 구축(G10 절차)
## STOP 보고 (운영자 확인 대기)
- CHECKPOINT-0: Phase 0 부트스트랩 5태스크 전부 DoD 통과로 완료 — 운영자 검수 대기(하네스 루프 정상 동작 여부 판정)
- ~~[R1/P1-T3] 실검증 패키지 준비 완료 — 운영자 수행 대기...~~ **해소(2026-08-10)**: 스코프 변경으로 R1 검증 불필요. plan.md Phase 1 참조
- [P1-T2] G6 해석 확인 요청(참고용 — P1-T2는 완료·유지 상태, 라이브 캡처 F-C4 재개 시에만 재소집 필요): SCK에는 비디오 캡처 완전 비활성화 속성이 없음(0×0 구성은 -3812 거부, 구성 변형 5종 실측). 에이전트 구현 = 최소 표면(2×2)·커서 없음·최저 프레임 간격 + 비디오 출력(.screen) 미등록 → 비디오 프레임이 프로세스로 전달되는 경로 부재(프로브: videoBuffers=0). 이것이 G6 "비디오 캡처 활성화 금지"를 충족하는지 운영자 판정 필요 — 불인정 시 P1-T2 재설계(대안 경로는 G10·큐 수정 사항)
