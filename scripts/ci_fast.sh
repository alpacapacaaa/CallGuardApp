#!/usr/bin/env bash
# scripts/ci_fast.sh — CallGuard 빠른 CI 레인 (P0-T2)
#
# 실행 순서: 빌드 → fast 레인 테스트 → 린트(swiftlint --strict, swiftformat --lint)
#
# 테스트 레인 (AGENTS.md §7):
#   Tests/CallGuardFastTests — 단위·룰·정책. 항상 실행 (이 스크립트).
#   Tests/CallGuardSlowTests — STT 통합·E2E·부하·벽시계 페이싱. DoD가 요구할 때만 실행:
#     swift test --filter '^CallGuardSlowTests\.'
#   레인은 타깃으로 분리한다 — swift test CLI에 태그 필터 없음 (P0-T2 실증).
#
# 종료 코드: 0 = 전 단계 통과 / 0 아님 = 실패한 단계 있음. 조용한 스킵 없음.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> [1/3] swift build"
swift build

echo "==> [2/3] fast 레인 테스트"
swift test --filter '^CallGuardFastTests\.'

echo "==> [3/3] 린트 (swiftlint --strict, swiftformat --lint)"
command -v swiftlint >/dev/null 2>&1 || { echo "ERROR: swiftlint 미설치 — brew install swiftlint" >&2; exit 1; }
command -v swiftformat >/dev/null 2>&1 || { echo "ERROR: swiftformat 미설치 — brew install swiftformat" >&2; exit 1; }
swiftlint --strict
swiftformat --lint .

echo "==> ci_fast: 전 단계 통과"
