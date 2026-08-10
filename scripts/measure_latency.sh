#!/usr/bin/env bash
# scripts/measure_latency.sh — M1 지연 측정 (PRD §3, F-S6)
#
# 구현 단계 (plan.md):
#   P2-T4  1단계: --stage stt — 캡처→전사 구간, 픽스처 20개 p50/p95
#   P4-T6  전 구간: 주입→경고 이벤트, 픽스처 100회 실행 p50 ≤ 2.0s && p95 ≤ 4.0s
#
# exit code 규약:
#   0 = 측정 완료, 지표가 목표 이내
#   1 = 측정 실패 또는 목표 미충족
#   2 = NOT_IMPLEMENTED (스텁 단계)
# 조용한 성공 금지 (plan.md P0-T4): 구현 완료 전 이 스크립트는 0으로 종료하지 않는다.
set -euo pipefail

echo "status: NOT_IMPLEMENTED — measure_latency.sh (P0-T4 stub)"
echo "plan: P2-T4(캡처→전사 p50/p95) → P4-T6(E2E 전 구간 p50 ≤ 2.0s, p95 ≤ 4.0s)"
exit 2
