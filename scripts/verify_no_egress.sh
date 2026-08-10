#!/usr/bin/env bash
# scripts/verify_no_egress.sh — M9 무송신 검증 (PRD §3, G2)
#
# 구현 단계 (plan.md):
#   P4-T8  픽스처 세션(EvaluateDetection) 실행 중 프로세스의 네트워크 소켓을 lsof로 폴링 —
#          오디오/텍스트를 다루는 프로덕션 파이프라인(Capture→STT→Detection→AlertPolicy)은
#          네트워크 호출을 하지 않으므로 세션 중 아웃바운드 소켓이 0건이어야 한다.
#          (모델 다운로드는 테스트/도구 코드에만 있고 세션 실행 경로에는 없음 — 사전에 캐시 확인)
#
# exit code 규약:
#   0 = 감시 완료, 아웃바운드 0건
#   1 = 아웃바운드 감지 또는 감시 실패
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift build --disable-keychain --product EvaluateDetection

LOG="$(mktemp)"
.build/debug/EvaluateDetection > "$LOG" 2>&1 &
PID=$!

EGRESS_FOUND=0
SAMPLES=0
while kill -0 "$PID" 2>/dev/null; do
  SAMPLES=$((SAMPLES + 1))
  NET_LINES="$(lsof -a -i -P -n -p "$PID" 2>/dev/null | tail -n +2 || true)"
  if [[ -n "$NET_LINES" ]]; then
    EGRESS_FOUND=1
    echo "egress detected:"
    echo "$NET_LINES"
  fi
  sleep 0.2
done
wait "$PID"
SESSION_EXIT=$?

echo "session_exit_code: $SESSION_EXIT"
echo "samples_taken: $SAMPLES"
echo "egress_connections_found: $EGRESS_FOUND"

if [[ "$SESSION_EXIT" -ne 0 ]]; then
  echo "status: FAILED — 세션 실행 실패(exit $SESSION_EXIT)"
  cat "$LOG"
  rm -f "$LOG"
  exit 1
fi

rm -f "$LOG"
if [[ "$EGRESS_FOUND" -eq 0 ]]; then
  echo "status: PASS — 세션 중(픽스처 10건) 아웃바운드 0건"
  exit 0
fi
echo "status: FAIL — 세션 중 아웃바운드 소켓 감지"
exit 1
