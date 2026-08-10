#!/usr/bin/env bash
# scripts/load_test.sh — M7 리소스·부하 테스트 (PRD §3)
#
# 구현 단계 (plan.md):
#   P4-T7  30분 루프 재생 — CPU 평균 ≤ 40%(1코어 환산) && 메모리 ≤ 2GB && 지연 드리프트 ≤ +20% [구현 완료]
#
# 사용법: load_test.sh [--duration <seconds>]  (기본값 1800 = 30분)
#
# exit code 규약:
#   0 = 부하 테스트 완료, 전 지표 목표 이내
#   1 = 테스트 실패 또는 지표 목표 초과
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift build --disable-keychain --product LoadTest
exec .build/debug/LoadTest "$@"
