# STT 벤치마크 (P2-T6)

측정: `scripts/measure_latency.sh --stage stt`(지연, 픽스처 10×2=20샘플) + `ml/eval/cer.py`(CER, wide+narrow8k 평균). 하드웨어: Apple M5, Metal.

| 모델 | 크기 | p50 | p95 | CER(overall avg) |
|---|---|---|---|---|
| tiny | 78MB | 183.8ms | 553.4ms | 0.619 |
| base | 148MB | 188.6ms | 540.4ms | **0.458** |
| small | 488MB | 183.3ms | 567.8ms | 0.466 |

## 선정: base

기준(plan.md P2-T6): "청크 처리 p95 ≤ 1.5s를 만족하는 것 중 CER 최소". 셋 다 지연 예산(1.5s)을 크게 여유 있게 통과 — base와 small의 p95 차이가 미미해 지연은 사실상 동률, CER이 낮은 base를 채택(용량도 small의 1/3).

## 주의 — CER이 PRD 목표(M6 ≤15%)에 크게 못 미침

base=0.458도 목표 대비 3배 이상 높다. 원인 후보(미검증, 추가 조사 필요):
- 픽스처가 macOS `say`(Yuna) TTS 합성음이라 실제 화자 음성과 음향 특성이 다름
- whisper.cpp 다국어 소형 모델의 한국어 성능 자체가 제한적일 가능성(medium/large-v3에서 개선 여부 미확인)
- CER 계산이 공백만 제거하고 문장부호는 그대로 비교 — 구두점 불일치가 오류율을 부풀렸을 가능성

G-2 게이트(운영자 판정)에서 다룰 사항. plan.md 리스크 표 대응책: 모델 상향(large 계열, 지연 재측정 필수) / 증강 확대 / 룰 비중 상향.

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
