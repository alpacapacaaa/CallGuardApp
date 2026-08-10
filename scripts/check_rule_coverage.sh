#!/usr/bin/env bash
# 룰 커버리지 검사(P3-T2, plan.md DoD): rules.yaml의 모든 룰 ID가
# RuleEngineTests.swift에서 문자열 리터럴로 참조되는지 확인한다.
# exit 0 = 전 룰 커버, exit 1 = 누락 룰 존재(구성 오류로 조용히 성공 금지 — AGENTS.md G13).
set -euo pipefail

RULES_FILE="rules.yaml"
TEST_FILE="Tests/CallGuardFastTests/RuleEngineTests.swift"

if [[ ! -f "$RULES_FILE" ]]; then
  echo "ERROR: $RULES_FILE 없음"
  exit 1
fi
if [[ ! -f "$TEST_FILE" ]]; then
  echo "ERROR: $TEST_FILE 없음"
  exit 1
fi

missing=0
while IFS= read -r id; do
  if ! grep -q "\"$id\"" "$TEST_FILE"; then
    echo "MISSING: 룰 ID '$id' 가 $TEST_FILE 에서 참조되지 않음"
    missing=1
  fi
done < <(grep -oE '^[[:space:]]*- id:[[:space:]]*[^[:space:]]+' "$RULES_FILE" | sed -E 's/^[[:space:]]*- id:[[:space:]]*//')

if [[ "$missing" -eq 0 ]]; then
  echo "==> check_rule_coverage: 전 룰 커버됨"
  exit 0
fi
exit 1
