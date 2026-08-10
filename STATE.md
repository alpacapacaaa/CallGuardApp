# STATE
## 현재 태스크
P0-T5
## 완료 태스크
- [x] P0-T1 (2026-08-09, commit 7ac9e04)
- [x] P0-T2 (2026-08-10, commit 0ea0725)
- [x] P0-T3 (2026-08-10, commit 1a80fb8)
- [x] P0-T4 (2026-08-10, commit 7136418)
## 작업 메모 (현재 태스크의 세부 체크리스트)
P0-T4 완료 체크리스트 (기록용):
- [x] VERIFY: git clean, 직전 DoD `swift test --filter AudioSourceTests` 재실행 exit 0 (10.059s)
- [x] 결정: exit code 규약(4종 공통, 헤더 주석 고정) — 0=완료·목표 충족 / 1=실패·미충족 / 2=NOT_IMPLEMENTED. 스텁은 절대 0 불가(조용한 성공 금지)
- [x] scripts/measure_latency.sh — M1, 구현 단계 주석(P2-T4 `--stage stt` → P4-T6 전 구간)
- [x] scripts/load_test.sh — M7, 구현 단계 주석(P4-T7 30분 루프)
- [x] scripts/verify_no_egress.sh — M9, 구현 단계 주석(P4-T8 아웃바운드 감시)
- [x] ml/eval/run.py — M2–M5·first-alert, docstring에 규약·단계 고정, 표준 라이브러리만(G10), 실행 비트 100755
- [x] 4종 실행: 전부 명시 출력 + exit 2 → 원문 아래
- [x] 회귀: `./scripts/ci_fast.sh` exit 0
## 마지막 DoD 실행 결과 (원문)
```
$ ./scripts/measure_latency.sh
status: NOT_IMPLEMENTED — measure_latency.sh (P0-T4 stub)
plan: P2-T4(캡처→전사 p50/p95) → P4-T6(E2E 전 구간 p50 ≤ 2.0s, p95 ≤ 4.0s)
exit: 2

$ ./scripts/load_test.sh
status: NOT_IMPLEMENTED — load_test.sh (P0-T4 stub)
plan: P4-T7(30분 루프 재생, CPU/메모리/드리프트 수집)
exit: 2

$ ./scripts/verify_no_egress.sh
status: NOT_IMPLEMENTED — verify_no_egress.sh (P0-T4 stub)
plan: P4-T8(세션 중 앱 프로세스 아웃바운드 감시, 0건 리포트)
exit: 2

$ python3 ml/eval/run.py
status: NOT_IMPLEMENTED — run.py (P0-T4 stub)
plan: P3-T1(로더 --dry-run 통계) → P3-T7(Recall/Precision/FPR/first-alert)
exit: 2
```
보조 확인(참고): `$ ./scripts/ci_fast.sh` → exit 0, "0/22 files require formatting", "ci_fast: 전 단계 통과"
## 미해결 이슈 / 다음 세션 지시
- P0-T5 진행: 합성 픽스처 v0 — 한국어 클립 ≥ 10개(정상 5/피싱 대사 5) + 정답 전사 + 매니페스트(출처 주석 G5). TTS 후보: macOS `say` 한국어 음성(가용 확인: `say -v ? | grep -i ko`, 예: Yuna). `say` 출력(AIFF/CAF)은 `afconvert -f WAVE -d LEI16`으로 WAV 변환 — 둘 다 macOS 기본 도구, 신규 의존성 아님(G10). 피싱 대사는 실제 사례 복제 없이 직접 작성(합성·G5). 매니페스트는 Tests/Fixtures/audio/ 에 배치하고 생성 도구·날짜·용도·전사 전문 기록
- 환경 노트: 로컬 python3는 3.12.8(AGENTS.md §4는 ml 툴링 3.11 전제) — 스텁은 3.11+ 호환 문법만 사용. ml venv·의존성 구성은 P3-T1 시점에 3.11로 구축 필요(그때 G10 절차: 운영자 승인 + lockfile)
- FileAudioSource는 100ms 청크·청크 종료 시점 방출로 고정(P0-T3) — P1-T2 SCK 캡처 구현 시 동일 계약(100ms 단위, capturedAt) 맞출 것
## STOP 보고 (운영자 확인 대기)
- (없음)
