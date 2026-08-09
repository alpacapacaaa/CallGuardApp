# plan.md — CallGuard 태스크 큐 (하네스 실행 계획)

> 이 문서는 에이전트가 순서대로 소비하는 태스크 큐다. STATE.md의 "현재 태스크" 포인터가 여기의 ID를 가리킨다.
> 규칙: **위에서 아래로, 의존성 충족된 태스크만, 1 세션 1 태스크.** `[병렬 가능]` 표시가 있는 태스크는 현재 태스크가 막혔을 때(STOP 대기 등) 대신 선택할 수 있다.
> 각 태스크의 **DoD는 명령 실행 결과로만 판정**한다(AGENTS.md G13). `게이트` 태스크는 에이전트가 측정 결과를 준비하고 STOP — 판정은 운영자.
> 일정은 주차가 아니라 순서로 관리한다. 하네스는 연속 실행되므로 달력 마감은 운영자가 CHECKPOINT에서 관리한다.

---

## 진행 규칙 요약

| 구분 | 의미 |
|---|---|
| DoD | 그대로 실행할 명령 + 기대 결과. 출력 원문을 STATE.md에 기록 |
| 의존 | 나열된 태스크가 전부 `[x]`여야 착수 가능 |
| [병렬 가능] | 메인 경로가 STOP 대기일 때 대체 선택 가능한 태스크 |
| 게이트 | 운영자 판정 필요 — 에이전트는 준비까지만 하고 STOP |
| 운영자 | 에이전트 수행 불가(실기기, 권한 클릭, 승인). 에이전트는 건너뛰고 다음 가능 태스크로 |

---

## Phase 0: 하네스 부트스트랩 (스크립트가 없으면 측정도 없다)

| ID | 태스크 | DoD | 의존 |
|---|---|---|---|
| P0-T1 | 저장소 골격 생성: AGENTS.md §4 구조대로 디렉토리·SwiftPM 타깃·빈 모듈, swiftlint/swiftformat 설정, .gitignore(`ml/datasets/` 포함), STATE.md 초기화 | `swift build` 성공 && `swiftlint` 위반 0 && `test -f STATE.md` | — |
| P0-T2 | CI 스크립트: `scripts/ci_fast.sh`(빌드+빠른 테스트+린트), 테스트 태그 체계(fast/slow) | `./scripts/ci_fast.sh` exit 0 | P0-T1 |
| P0-T3 | `AudioSource` 프로토콜 + `FileAudioSource`(벽시계 실시간 페이싱) + `AudioChunk`/`TranscriptSegment`/`RiskScore` 타입 정의 | `swift test --filter AudioSourceTests` 통과 — 10s WAV 리플레이가 9.5–10.5s 소요됨을 검증하는 테스트 포함 | P0-T1 |
| P0-T4 | 측정 스크립트 스텁 4종: `scripts/measure_latency.sh`, `scripts/load_test.sh`, `scripts/verify_no_egress.sh`, `ml/eval/run.py` — 미구현 단계는 "NOT_IMPLEMENTED" 명시 출력(조용히 성공 금지) | 각 스크립트 실행 시 명시적 상태 출력, exit code 규약 주석 존재 | P0-T1 |
| P0-T5 [병렬 가능] | 합성 픽스처 v0: TTS로 한국어 클립 ≥ 10개(정상 5/피싱 대사 5) + 정답 전사, 출처 주석(G5) | `ls Tests/Fixtures/audio/*.wav | wc -l` ≥ 10 && 매니페스트 존재 | P0-T1 |

**CHECKPOINT-0 (운영자)**: 부트스트랩 검수, 하네스 루프 1회 정상 동작 확인.

---

## Phase 1: 캡처 PoC — R1 검증 (프로젝트 전제)

| ID | 태스크 | DoD | 의존 |
|---|---|---|---|
| P1-T1 (운영자) | 실기기 Continuity 환경 구축 + 통화 미러링 수신 확인 | `docs/env-checklist.md` 작성 | — |
| P1-T2 | SCK 오디오 전용 캡처 모듈: 시스템 오디오 → 48kHz PCM → WAV 저장 CLI 데모 타깃 | 운영자가 음악 재생 중 CLI 실행 → 생성된 WAV 재생 가능. 자동 판정: WAV 헤더·샘플레이트 검사 테스트 통과 | P0-T3 |
| P1-T3 (운영자) | **R1 핵심 검증**: 실통화 중 P1-T2 CLI로 상대방 음성 캡처 시도 | remote.wav에 상대방 음성 존재 여부를 운영자가 청취 판정, 결과를 `docs/spike-r1-report.md`에 기록 | P1-T1, P1-T2 |
| P1-T4 | 마이크 트랙 캡처: AVAudioEngine 탭 → local.wav 분리 저장, 동일 CLI에 통합 | 캡처 세션 1회에 remote.wav/local.wav 2파일 생성, 트랙 태깅 테스트 통과 | P1-T2 |
| P1-T5 [병렬 가능] | 권한 흐름 조사: TCC 화면녹화·마이크 권한 요청 코드 경로, 거부 시 동작 문서화 | `docs/permissions.md` 작성 + 권한 미보유 시 크래시 없이 안내 상태 진입 테스트 | P1-T2 |
| **G-1 게이트** | R1 판정 준비: spike 리포트에 증빙(파일 경로, 재현 절차) 정리 후 STOP | STATE.md STOP 보고에 Go/No-Go 판단 재료 정리. **판정: 운영자.** No-Go 시 운영자가 폴백(BlackHole) 태스크를 큐에 추가한다 — 에이전트 임의 착수 금지 | P1-T3, P1-T4 |

---

## Phase 2: STT 파이프라인

| ID | 태스크 | DoD | 의존 |
|---|---|---|---|
| P2-T1 | Preprocess: 48→16kHz 리샘플링, VAD, 2s 청크화, 타임스탬프 | `swift test --filter PreprocessTests` — 청크 경계 오차 ≤ 50ms 검증 포함 | P0-T3 |
| P2-T2 [병렬 가능] | whisper.cpp 통합: Metal 빌드, SwiftPM 래핑, 모델 파일 SHA256 고정·검증 로직 | 단발 추론 테스트 통과 + 해시 불일치 시 로드 거부 테스트 통과 | P0-T1 |
| P2-T3 | 트랙별 스트리밍 STT: remote/local 독립 인스턴스, `TranscriptSegment` 방출 | slow 테스트: 픽스처 리플레이 → 두 트랙 전사 비혼합·순서 보장 검증 | P2-T1, P2-T2, P0-T5 |
| P2-T4 | 지연 계측(F-S6): 단계별 타임스탬프 → CSV, p50/p95 집계 → `scripts/measure_latency.sh` 1단계 구현(캡처→전사 구간) | `./scripts/measure_latency.sh --stage stt` 가 픽스처 20개에 대해 p50/p95 수치 출력 | P2-T3, P0-T4 |
| P2-T5 | CER 측정기: `ml/eval/cer.py` + 통화 대역(8kHz 다운샘플) 증강 픽스처 추가 | `python ml/eval/cer.py` 가 픽스처 전체 CER 수치 출력 | P2-T3, P0-T5 |
| P2-T6 | STT 벤치마크: base vs small(필요시 양자화) — 지연·CER 매트릭스 작성 | `docs/stt-benchmark.md`에 조합별 p95·CER 표. **선정 기준: 청크 처리 p95 ≤ 1.5s를 만족하는 것 중 CER 최소** | P2-T4, P2-T5 |
| **G-2 게이트** | STT 확정 판정 준비 후 STOP | STATE.md에 벤치마크 요약 + 추천안. 통과 기준(운영자 확인): 청크 처리 p95 ≤ 1.5s && 발화 종료→전사 p95 ≤ 2.0s. CER > 15%면 개선 계획 첨부 | P2-T6 |

---

## Phase 3: 탐지 엔진

| ID | 태스크 | DoD | 의존 |
|---|---|---|---|
| P3-T1 [병렬 가능] | 평가셋 v1: 그놈 목소리 유래(운영자가 이용조건 확인 후 배치) + 합성 시나리오로 피싱 ≥ 50 / 정상 ≥ 100 통화 단위 라벨, `ml/eval/run.py` 로더 구현 | `python ml/eval/run.py --dry-run` 이 데이터셋 통계(건수/라벨 분포) 출력 | P0-T4 |
| P3-T2 | rules.yaml 스키마 + RuleEngine: 카테고리 5종, 로드 시 서명 검증(F-S5) | fast 테스트: 룰별 양성 1+음성 1 전부 통과, 룰 커버리지 검사 스크립트 exit 0 | P0-T3 |
| P3-T3 | KoBERT 파인튜닝 파이프라인(`ml/training/`): 데이터 로드→학습→검증 F1 리포트, 단일 명령 재현 | `python ml/training/train.py --smoke` (소량 1 epoch) 성공 + 검증 F1 출력 | P3-T1 |
| P3-T4 | Core ML 변환·인프로세스 추론: coremltools 변환 스크립트, Swift tokenizer 처리, 추론 정합성 검증 | 변환 모델의 Swift 추론 로짓이 Python 대비 허용 오차 내 일치 테스트 + 윈도당 추론 ≤ 300ms 측정 출력 | P3-T3 |
| P3-T5 | 탐지 통합: 60s 슬라이딩 윈도, 1차 룰+2차 판정 결합, evidence 채움 | slow 테스트: 전사 리플레이에서 evidence에 실제 근거 세그먼트 포함 검증 | P3-T2, P3-T4 |
| P3-T6 | AlertPolicy: 임계값 0.5/0.8, 히스테리시스, [무시] 후 세션 내 재경고 억제 | fast 테스트: 스코어 시퀀스 시나리오 전부 통과(재경고 0건 포함) | P3-T5 |
| P3-T7 | 평가 하니스 완성: `ml/eval/run.py` 가 통화 단위 Recall/Precision/FPR/first-alert 산출 | 평가셋 v1 전량 실행, 4지표 수치 출력 | P3-T1, P3-T5 |
| **G-3 게이트** | 탐지 v1 판정 준비 후 STOP | STATE.md에 지표 원문. 중간 기준: Recall ≥ 0.80. 미달 시 격차 분석(카테고리별 미탐 목록) 첨부 — **개선 방향 선택은 운영자** | P3-T7 |
| P3-T8 (반복) | 탐지 개선 이터레이션: 운영자가 G-3에서 지정한 방향(룰 확충/데이터 증강/모델 조정)만 수행. 1 이터레이션 = 1 태스크 | 이터레이션마다 `ml/eval/run.py` 재실행, 지표 변화를 STATE.md에 이전 수치와 나란히 기록. **G12: 임계값·평가셋을 유리하게 수정 금지** | G-3 판정 |

---

## Phase 4: 앱 통합

| ID | 태스크 | DoD | 의존 |
|---|---|---|---|
| P4-T1 | 세션 자동 감지(F-M2) + 수동 시작 폴백 | fast 테스트: 오디오 활성 신호 시퀀스 → 세션 시작/종료 전이 검증. 실통화 확인은 운영자 스모크 항목으로 `docs/manual-smoke.md`에 추가 | P1 완료(G-1 Go) |
| P4-T2 [병렬 가능] | 경고 UI(F-M5): 메뉴바 3상태, 주의 배너, 위험 전면 패널(유형+근거 2–3건+권장행동+[무시]) | UI 스냅샷/뷰모델 테스트 통과, `RiskScore` 픽스처 주입으로 3상태 재현 스크린샷을 `docs/ui/`에 저장 | P3-T6 |
| P4-T3 [병렬 가능] | 온보딩(F-M6): 환경 진단 체크리스트, 권한 가이드, 내장 샘플 자가 진단 | 자가 진단이 FileAudioSource 경유로 파이프라인 전 구간 통과를 표시하는 통합 테스트 | P1-T5, P2-T3 |
| P4-T4 | 동의 게이트(F-M8) + 폐기(F-M7) + 옵트인 저장 | fast 테스트 3종: 동의 전 파이프라인 시작 불가 / 세션 종료 후 임시 파일 0건 / 옵트인 DB에 평문 전사 미검출 | P4-T1 |
| P4-T5 | 세션 리포트(F-S1) + 오탐 피드백(F-S2) + 민감도(F-S3) | Flow 시나리오 통합 테스트 통과 | P4-T2, P4-T4 |
| P4-T6 | E2E 지연 측정 완성: `scripts/measure_latency.sh` 전 구간(주입→경고 이벤트) | 픽스처 100회 실행 → **p50 ≤ 2.0s && p95 ≤ 4.0s** 수치 출력 (M1) | P4-T1–T4, P2-T4 |
| P4-T7 | 부하 테스트: `scripts/load_test.sh` 30분 루프 재생, CPU/메모리/드리프트 수집 | **CPU ≤ 40% && 메모리 ≤ 2GB && 드리프트 ≤ +20%** 수치 출력 (M7) | P4-T6 |
| P4-T8 | 무송신 검증: `scripts/verify_no_egress.sh` — 세션 중 앱 프로세스 아웃바운드 감시 | 픽스처 세션 중 오디오/텍스트 관련 아웃바운드 **0건** 리포트 (M9) | P4-T4 |
| P4-T9 (운영자) | 실기기 스모크 + 사용성 테스트(M8) | `docs/manual-smoke.md` 전 항목, 외부 사용자 온보딩 8/10 | P4-T3, P4-T6 |
| **CHECKPOINT-4 (운영자)** | 지표 종합 검토: M1–M9 리포트(`docs/metrics-final.md`)를 에이전트가 생성 → 운영자 판정 | 미달 지표는 P3-T8 또는 개별 fix 태스크로 큐 추가 | P4-T6–T9 |

---

## Phase 5: 데모 준비 (기능 동결 — 이후 `fix:`/`docs:`만 허용)

| ID | 태스크 | DoD | 의존 |
|---|---|---|---|
| P5-T1 | 데모 시나리오 스크립트 2종: ① 피싱(검찰 사칭, 60s 내 위험 경고 도달 타임라인 명시) ② 정상(은행 상담, 경고 미발생) — 각각 픽스처 오디오 제작 | `scripts/demo.sh scenario1|scenario2` 로 FileAudioSource 리플레이 데모가 기대 경고 시점 ±10s 내 재현, 3회 연속 성공 로그 | CHECKPOINT-4 |
| P5-T2 | 데모 삼중화: [A] 라이브(실통화, 운영자) [B] 세미라이브(`scripts/demo.sh`) [C] 화면 녹화 영상 — B·C 산출물은 에이전트, A 절차서는 문서로 | B 3회 연속 재현 + C 영상 파일 존재 + `docs/demo-runbook.md`(장애 증상→조치→전환 절차) 완성 | P5-T1 |
| P5-T3 (운영자) | 리허설 ≥ 3회(1회는 캡처 강제 실패 주입 → B 전환 연습), 발표장 점검 | 리허설 기록 3건 docs/에 존재 | P5-T2 |
| P5-T4 [병렬 가능] | 발표 자료 입력 생성: 지표 요약표, 아키텍처 다이어그램, 한계(R2/R5) 정리 — 슬라이드 자체는 운영자 | `docs/presentation-inputs.md` 완성 | CHECKPOINT-4 |

---

## 리스크 → 하네스 대응 규칙

| 리스크 | 하네스에서의 처리 |
|---|---|
| R1 실패 (G-1 No-Go) | 에이전트는 STOP 유지. 운영자가 폴백 태스크(P1-F1: BlackHole 캡처 검증)를 큐에 삽입한 뒤에만 진행. P2·P3는 픽스처 기반이므로 [병렬 가능] 경로로 계속 전진 |
| CER > 15% (G-2) | 운영자 선택지: 모델 상향(지연 재측정 필수) / 증강 확대 / 룰 비중 상향. 에이전트는 지정된 것만 |
| Recall < 0.80 (G-3) | P3-T8 반복. 단 G12 — 평가셋·임계값 조작으로 지표를 만드는 것 금지 |
| FPR > 5% | Recall 튜닝 중단, 위험 임계 상향·2차 판정 통과분만 전면 경고로 조정 (AGENTS.md §8-3) |
| 동일 오류 3회 실패 | AGENTS.md §3-7 STOP — 하네스가 같은 벽에 토큰을 태우는 것을 방지 |
| 로컬 모델의 API 환각 | 신규 API 사용 전 문서/헤더 확인 의무(AGENTS.md §9), 리뷰 시 grep 대상: 미컴파일 심볼 |

## 운영자 리뷰 주기 (사람 쪽 절차)

- **매 세션 후 (경량, ~5분)**: STATE.md diff만 확인 — STOP 보고 유무, DoD 출력 원문이 실제로 붙어 있는지, 커밋 메시지에 태스크 ID.
- **매일 1회 (~20분)**: 당일 커밋 diff 리뷰. 우선 grep: `URLSession`(G2), 전사 로깅 패턴(G1), `Package.resolved`/`requirements.txt` 변경(G10), 테스트/스크립트 파일 수정(G12), 컴파일 안 되는 심볼.
- **게이트/CHECKPOINT**: 판정 + 필요 시 큐 수정(태스크 추가·삭제·재배열은 운영자만).
- **주 1회**: 지표 추이 확인, plan.md·AGENTS.md 개정 필요 여부 검토(반복되는 STOP 패턴은 가드레일 또는 태스크 세분화로 환류).

---

*문서 버전 v2.0 (하네스판) — PRD.md(압축판), AGENTS.md(하네스판) 기준. 큐 수정 권한은 운영자에게만 있다.*
