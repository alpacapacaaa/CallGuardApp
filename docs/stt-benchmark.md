# STT 벤치마크 (P2-T6)

측정: `scripts/measure_latency.sh --stage stt`(지연, 픽스처 10×2=20샘플) + `ml/eval/cer.py`(CER, wide+narrow8k 평균). 하드웨어: Apple M5, Metal.

| 모델 | 크기 | p50 | p95 | CER(overall avg) |
|---|---|---|---|---|
| tiny | 78MB | 183.8ms | 553.4ms | 0.619 |
| base | 148MB | 188.6ms | 540.4ms | **0.458** |
| small | 488MB | 183.3ms | 567.8ms | 0.466 |

## 선정: base

기준(plan.md P2-T6): "청크 처리 p95 ≤ 1.5s를 만족하는 것 중 CER 최소". 셋 다 지연 예산(1.5s)을 크게 여유 있게 통과 — base와 small의 p95 차이가 미미해 지연은 사실상 동률, CER이 낮은 base를 채택(용량도 small의 1/3).

## G-2 해결 (2026-08-11): 원인은 모델이 아니라 2s 청킹이었음

**결론: 청크 길이를 2s→8s로 변경해 CER 0.458→0.130으로 해결.** PRD F-M3/AGENTS.md §4 반영 완료.

> 정정(2026-08-11): 최초 보고한 0.114는 G-2 조사 중 임시로 추가했던 "무청킹" 진단 대역이 섞인
> 평균값이었다(진단 대역 제거 후 재현 불가). wide+narrow8k 2개 대역만의 정확한 값은 0.130이며,
> 여전히 목표(≤15%) 통과다. 아래 표·수치를 이 값으로 정정.

### 조사 경위

1. **모델 교체 시도 2건 — 둘 다 실패**: 한국어 파인튜닝 ggml 모델(`royshilkrot/whisper-medium-korean-ggml`,
   `wabisabisocial/whisper-base-korean-ggml`)을 실제로 다운로드해 우리 픽스처로 재측정 → CER이 각각
   1.046, 0.882로 오히려 다국어 base(0.458)보다 나쁨. 둘 다 좁은 도메인(Zeroth-Korean 등 낭독체
   코퍼스) 파인튜닝이라 우리 입력 특성에 일반화가 안 됨.
2. **"TTS 픽스처가 원인" 가설도 반증됨**: 공개 실음성 데이터셋(OpenSLR/kresnik `zeroth_korean` 테스트
   셋 10건, 진짜 사람 낭독)으로 현재 base 모델을 재측정 → CER=0.931로 TTS 픽스처(0.458)보다 **더
   나쁨**. 실음성이 원인이 아님이 확인됨.
3. **진짜 원인 발견**: 실음성 전사 결과를 직접 읽어보니 문장 끝마다 "감사합니다", "[모두]" 같은 무관한
   텍스트가 반복 삽입됨. 동일 클립을 **청킹 없이 통째로 whisper_full() 1회 호출**하면 CER
   0.931→0.252로 급감(73% 감소) — `PreprocessPipeline`이 오디오를 2s 단위로 독립적으로 잘라
   whisper에 넣다 보니 문장이 중간에 끊기고 문맥(cross-chunk context)이 사라져 품질이 근본적으로
   저하되고 있었음. 스트리밍(실시간성) 요구는 유지해야 하므로 완전 무청킹 대신 청크 길이를 늘리는
   절충안을 검증.

### 청크 길이별 실측 (base 모델, 우리 TTS 픽스처 10건)

| 청크 길이 | CER(wide) | STT 지연 p50/p95 |
|---|---|---|
| 2s (기존) | 0.458 | 188.6ms / 540.4ms |
| 8s (신규) | **0.130** | **99.3ms / 218.3ms** |
| 무청킹(전체 1회) | 0.082 | (스트리밍 불가, 참고용) |

지연이 오히려 개선된 이유: whisper_full() 호출 횟수가 줄어(청크당 고정 오버헤드 감소) 총 처리
시간이 줄어듦. 실음성(Zeroth-Korean) 10건 기준으로도 2s=0.931 → 8s=0.401로 동일 경향 확인.

### 추가 조치

- `Sources/STT/TrackTranscriber.swift`: VAD(`isSpeech`) 게이트 추가 — 무음 청크는 whisper 호출 자체를
  생략(이번 조사에서는 효과 미측정이었지만 일반적으로 안전한 방어 조치라 유지).
- `Sources/STT/WhisperEngine.swift`: `whisper_full_get_segment_no_speech_prob` 기반 저신뢰 세그먼트
  필터링 추가(마찬가지로 이번 데이터에서는 효과 미측정, 안전망으로 유지).
- M1(E2E 지연)·M3(Recall) 재측정: E2E는 p50=122.0ms/p95=140.1ms로 개선(기존 209.7/713.8ms).
  **Recall은 0.400 그대로(변화 없음)** — CER 개선이 rule/classifier 매칭까지 자동으로 고치진
  않음. G-3(Recall)는 별도 이터레이션(P3-T8, 이후 완료 — STATE.md 참조).

## 후속: 고정 길이 청킹 → VAD 기반 가변 청킹 (2026-08-11)

라이브 캡처 UI에서 8s 고정 청킹이 자막 체감을 나쁘게 한다는 사용자 피드백(문장 중간 대신 항상
8초마다 끊기고, 짧은 발화도 8초를 기다려야 화면에 뜸). `PreprocessPipeline`을 무음(VAD) 지점에서
조기 컷하도록 변경 — 최소 3.0초 이상 쌓였고 최근 0.5초가 무음이면 그 지점에서 컷, 무음이 없으면
기존대로 8초 상한에서 강제 컷(CER 실측 근거 보존). 우리 TTS 픽스처(단문 1개씩이라 대부분 최소
길이 도달 전 끝남)로는 CER 불변(0.130) 확인 — 회귀 없음. 여러 문장이 이어지는 실통화에서 체감
개선 기대(신규 테스트: PreprocessTests의 조기 컷/미컷 경계 케이스 2건).

## 재현

```
$ ./scripts/measure_latency.sh --stage stt          # 기본값 tiny
$ .build/debug/MeasureSTTLatency ggml-base.bin <sha256>
$ .build/debug/MeasureSTTLatency ggml-small.bin <sha256>
$ python3 ml/eval/cer.py                             # 기본값 tiny — TranscribeFixtures도 동일하게 모델명 인자로 교체 가능
```

base/small 모델 SHA256(이 벤치마크 시점, TOFU):
- ggml-base.bin: `60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe`
- ggml-small.bin: `1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b`
