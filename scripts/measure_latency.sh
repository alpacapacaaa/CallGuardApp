#!/usr/bin/env bash
# scripts/measure_latency.sh — M1 지연 측정 (PRD §3, F-S6)
#
# 구현 단계 (plan.md):
#   P2-T4  1단계: --stage stt — 캡처→전사 구간, 픽스처 20개(10개×2회) p50/p95 [구현 완료]
#   P4-T6  전 구간: --stage e2e — 주입→경고 이벤트, 픽스처 100회(10개×10회) p50 ≤ 2.0s && p95 ≤ 4.0s [구현 완료]
#
# exit code 규약:
#   0 = 측정 완료
#   1 = 측정 실패
#   2 = 사용법 오류
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

STAGE="${2:-}"
if [[ "${1:-}" == "--stage" && "$STAGE" == "stt" ]]; then
  swift build --disable-keychain --product MeasureSTTLatency
  exec .build/debug/MeasureSTTLatency
fi
if [[ "${1:-}" == "--stage" && "$STAGE" == "e2e" ]]; then
  swift build --disable-keychain --product MeasureE2ELatency
  exec .build/debug/MeasureE2ELatency
fi

echo "usage: measure_latency.sh --stage {stt|e2e}"
exit 2
