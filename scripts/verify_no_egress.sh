#!/usr/bin/env bash
# scripts/verify_no_egress.sh — M9 무송신 검증 (PRD §3, G2)
#
# 구현 단계 (plan.md):
#   P4-T8  픽스처 세션 중 앱 프로세스 아웃바운드 감시 — 오디오/텍스트 관련 아웃바운드 0건
#
# exit code 규약:
#   0 = 감시 완료, 아웃바운드 0건
#   1 = 아웃바운드 감지 또는 감시 실패
#   2 = NOT_IMPLEMENTED (스텁 단계)
# 조용한 성공 금지 (plan.md P0-T4): 구현 완료 전 이 스크립트는 0으로 종료하지 않는다.
set -euo pipefail

echo "status: NOT_IMPLEMENTED — verify_no_egress.sh (P0-T4 stub)"
echo "plan: P4-T8(세션 중 앱 프로세스 아웃바운드 감시, 0건 리포트)"
exit 2
