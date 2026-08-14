# CallGuard

통화 오디오를 온디바이스 STT + 룰/분류기 기반으로 분석해 실시간으로 보이스피싱을 경고하는 macOS 네이티브 앱입니다. 오디오·전사·판정 데이터는 기기 밖으로 전송되지 않습니다.

## 요구 사항

- macOS 14+ (Apple Silicon)
- Swift 5.10+

## 빌드 & 실행

```bash
swift build
swift run CallGuardApp
```

## 테스트

```bash
swift test
```

## 프로젝트 구조

- `Sources/` — Capture → Session → Preprocess → STT → Detection → AlertPolicy → CallGuardUI 파이프라인 모듈
- `ml/` — 탐지 모델 평가 스크립트
- `scripts/` — 지연/부하/네트워크 검증 스크립트
- `docs/` — 벤치마크·온보딩 등 상세 문서
- `PRD.md` — 요구사항 스펙

자세한 아키텍처와 규칙은 `AGENTS.md`, `PRD.md`를 참고하세요.
