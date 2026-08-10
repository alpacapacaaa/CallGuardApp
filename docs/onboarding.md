# 온보딩 (F-M6, P4-T3)

## 환경 진단 체크리스트

- [ ] macOS 14(Sonoma) 이상, Apple Silicon
- [ ] `swift build --disable-keychain` 성공 (키체인 이슈 시 `docs/permissions.md` 무관 — `--disable-keychain` 필요 이유는 STATE.md P2-T2 참조)
- [ ] whisper 모델 캐시 존재: `~/Library/Caches/CallGuard/whisper-model-cache/ggml-base.bin` (없으면 최초 실행 시 자동 다운로드)
- [ ] `rules.yaml`/`rules.yaml.sig` 저장소 루트에 존재(서명 불일치 시 RuleEngine 로드 거부)
- [ ] 자가 진단 통과: 아래 "내장 샘플 자가 진단" 참조

## 권한 가이드

파일 재생 입력(FileAudioSource)은 화면 녹화·마이크 TCC 권한이 필요 없다. 라이브 캡처(F-C4, 보류 상태)
재개 시에만 `docs/permissions.md`의 권한 흐름·거부 시 안내 상태(`PermissionGuidance`) 계약이 적용된다.

## 내장 샘플 자가 진단

`Sources/Onboarding/SelfDiagnosis.swift`가 내장 픽스처(`Tests/Fixtures/audio/normal-delivery-01.wav`)를
`FileAudioSource`로 실시간 페이싱 재생하며 캡처→전사→탐지→경고 전 구간을 예외 없이 완주하는지
단계별(`capture/stt/detection/alertPolicy`)로 보고한다. 통합 테스트:
`swift test --disable-keychain --filter SelfDiagnosisTests` (slow 레인, 최초 1회 tiny 모델 다운로드).
