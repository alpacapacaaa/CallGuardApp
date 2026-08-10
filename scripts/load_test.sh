#!/usr/bin/env bash
# scripts/load_test.sh — M7 리소스·부하 테스트 (PRD §3)
#
# 구현 단계 (plan.md):
#   P4-T7  30분 루프 재생 — CPU 평균 ≤ 40%(1코어 환산) && 메모리 ≤ 2GB && 지연 드리프트 ≤ +20%
#
# exit code 규약:
#   0 = 부하 테스트 완료, 전 지표 목표 이내
#   1 = 테스트 실패 또는 지표 목표 초과
#   2 = NOT_IMPLEMENTED (스텁 단계)
# 조용한 성공 금지 (plan.md P0-T4): 구현 완료 전 이 스크립트는 0으로 종료하지 않는다.
set -euo pipefail

echo "status: NOT_IMPLEMENTED — load_test.sh (P0-T4 stub)"
echo "plan: P4-T7(30분 루프 재생, CPU/메모리/드리프트 수집)"
exit 2
