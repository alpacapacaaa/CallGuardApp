# 권한 흐름 조사 (P1-T5)

> CallGuard 캡처 데모(`CaptureDemo`)가 사용하는 macOS TCC 권한 2종 — **화면 녹화**(ScreenCaptureKit)와
> **마이크**(AVAudioEngine) — 의 요청 경로, 거부 시 동작, 그리고 "권한 미보유 시 크래시 없이 안내 상태로
> 종료" 계약의 근거를 문서화한다. AGENTS.md §3(조용한 실패 금지)·§9(API 실존 확인) 준수.

## 1. 요약: 권한 → 오류 → 종료코드 매핑

| 권한 | 요청 지점 | 거부 시 도달 오류 | 안내 상태 종료코드 |
|---|---|---|---|
| 화면 녹화 | `SystemAudioCapture.chunks()` → `SCShareableContent.excludingDesktopWindows` 최초 호출 | `CaptureError.screenCaptureDenied` | **3** |
| 마이크 | `MicAudioCapture.init()` / 엔진 `start()` → `MicPermission.ensureGranted()` | `CaptureError.microphoneDenied` | **4** |

공통 계약: 두 경우 모두 **예외 전파·크래시 없이** `PermissionGuidance`(제목 + 복구 절차)를 표준오류로 출력하고
해당 종료코드로 종료한다. 매핑은 `PermissionGuidance.from(_:)` 단일 총함수로, fast 레인
`PermissionGuidanceTests`가 결정적으로 검증한다.

전체 종료코드: `0` 성공 / `1` 캡처 실패(일반) / `3` 화면녹화 거부 / `4` 마이크 거부 / `64` 사용법 오류.

## 2. 화면 녹화 (ScreenCaptureKit)

### 요청 경로
- 최초 `SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly:)` 호출이 TCC 화면 녹화
  승인 프롬프트를 유발한다. 구현 위치는 `Sources/Capture/SystemAudioCapture.swift`의
  `SystemAudioEngine.start()`.
- 오디오 전용 캡처지만 SCK는 화면 녹화 권한을 요구한다(시스템 오디오가 화면 캡처 권한에 묶임, P1-T2 실측).

### 거부 시 동작
- 승인 거부 시 해당 호출이 `NSError`를 던진다 — 도메인 `SCStreamErrorDomain`, 코드 `-3801`
  (`SCStreamError.userDeclined`, SDK 헤더 `SCError.h`에서 상수 실존 확인).
- `SystemAudioEngine.captureError(from:stage:)`가 이 오류를 포착해 `CaptureError.screenCaptureDenied`로
  매핑한다. **ObjC 예외 경로가 아니라 catch 가능한 throw**이므로 크래시로 이어지지 않는다.
- 이후 `CaptureDemo.report()`가 `PermissionGuidance.from()`으로 안내 상태(exit 3)를 만든다.

### 크래시 없음 근거
SCK 권한 거부는 throw → typed error → 안내의 순수 포착 경로다. 마이크와 달리 "접근하면 예외"인
하드웨어 노드가 없어 추가 게이트가 필요 없다.

## 3. 마이크 (AVAudioEngine)

### 요청 경로
- `MicPermission.ensureGranted()`(`Sources/Capture/MicAudioCapture.swift`)가 먼저
  `AVAudioApplication.shared.recordPermission`을 읽는다.
  - `.granted` → 통과.
  - `.denied` → 즉시 `CaptureError.microphoneDenied`.
  - `.undetermined` → `AVAudioApplication.requestRecordPermission()`(async)가 프롬프트를 띄우고,
    결과 `false`면 `microphoneDenied`.
- 경유 지점은 2곳: `MicAudioCapture.init()`(포맷 조회 전)과 `MicCaptureEngine.start()`(tap 설치 전).

### 거부 시 동작
- `CaptureError.microphoneDenied` → `CaptureDemo.report()` → 안내 상태(exit 4).

### 크래시 없음 근거 (핵심)
`AVAudioEngine.h`는 **권한 없이 `inputNode`로 입력을 시도하면 엔진이 오류 또는 예외를 던질 수 있다**고
명시한다. 예외는 Swift `catch`로 포착되지 않아 크래시가 된다. 따라서 본 구현은 `inputNode`를
**건드리기 전**에 `MicPermission.ensureGranted()` 게이트를 강제한다 — 권한 없으면 하드웨어에 접근조차
하지 않으므로 예외 경로 자체가 열리지 않는다. 이것이 "마이크 거부 시 크래시 없이 안내"의 실질적 보장이다.

## 4. 권한 주체 (터미널 실행 시)

CLI를 터미널에서 실행하면 TCC 승인은 **실행 파일이 아니라 상위 앱(터미널)** 에 귀속된다. 따라서 안내
문구는 "이 데모를 실행한 상위 앱(예: 터미널)을 허용"하도록 지시한다. 추후 앱 번들(`CallGuardApp`)로
통합되면 주체가 번들로 바뀌며, 온보딩(F-M6, P4-T3)에서 자가진단으로 재확인한다.

## 5. 재시험을 위한 TCC 리셋 (운영자 절차)

에이전트는 TCC 상태를 결정적으로 조작할 수 없다. 거부 경로를 실기기에서 재현하려면 운영자가 권한을
직접 리셋해야 한다(**시스템 상태 변경이므로 운영자만 수행**):

```bash
# 특정 서비스 권한 리셋 — 리셋 후 해당 API를 다시 호출하면 프롬프트가 재표시된다.
tccutil reset ScreenCapture          # 화면 녹화
tccutil reset Microphone             # 마이크
# 또는 특정 번들만 리셋:
tccutil reset ScreenCapture <bundle-id>
```

> 주의: `tccutil reset <service>`(번들 미지정)는 해당 서비스의 **모든 앱** 승인을 초기화한다.
> 리셋 후 `CaptureDemo`를 재실행해 프롬프트 → 거부 → 안내 상태(exit 3/4) 경로를 확인한다.

## 6. 검증 범위와 한계

- **결정적 검증 가능(fast 레인)**: 권한 오류 → 안내 상태 매핑의 총함수성, 종료코드·안내 문구.
  `PermissionGuidanceTests` 5건이 커버.
- **실기기 검증 필요(운영자)**: 실제 프롬프트 표시, 거부 선택 시 exit 3/4 도달. 위 5절의 리셋 절차로
  재현 가능 — `docs/manual-smoke.md`(P4-T9)에 스모크 항목으로 반영 예정.
- 한계: 승인/거부 **실시간 분기**는 OS가 소유하므로 단위 테스트로 강제 불가. 따라서 거부 "경로의
  논리"(매핑)는 코드로, "프롬프트 동작"(OS 상호작용)은 문서·수동 스모크로 분담한다.

## 7. 참고 심볼 (AGENTS.md §9 실존 확인 완료)

- `SCShareableContent.excludingDesktopWindows(_:onScreenWindowsOnly:)` — `SCShareableContent.h`
- `SCStreamErrorDomain`, `SCStreamError.userDeclined = -3801` — `SCError.h`
- `AVAudioApplication.shared`, `.recordPermission`, `requestRecordPermission()` — `AVAudioApplication.h` (macOS 14)
- `AVAudioEngine.inputNode` 접근 시 권한 필요 경고 — `AVAudioEngine.h`
