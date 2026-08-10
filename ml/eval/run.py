#!/usr/bin/env python3
"""ml/eval/run.py — 통화 단위 평가 (PRD §3: M2·M3·M4·M5, first-alert).

구현 단계 (plan.md):
    P3-T1  로더: --dry-run 이 데이터셋 통계(건수/라벨 분포) 출력
    P3-T7  평가 하니스: 평가셋 전량 — 통화 단위 Recall/Precision/FPR/first-alert
    P3-T8  이터레이션: 재실행마다 지표 변화를 이전 수치와 나란히 기록

exit code 규약:
    0 = 평가 완료, 지표 산출 성공
    1 = 평가 실행 실패 또는 데이터셋 오류
    2 = NOT_IMPLEMENTED (스텁 단계)

조용한 성공 금지 (plan.md P0-T4): 구현 완료 전 이 스크립트는 0으로 종료하지 않는다.
G12: 구현 시작 후 이 스크립트는 DoD·평가 수단 — 임계값·평가셋 유리한 수정 금지.
"""

import sys


def main() -> int:
    print("status: NOT_IMPLEMENTED — run.py (P0-T4 stub)")
    print("plan: P3-T1(로더 --dry-run 통계) → P3-T7(Recall/Precision/FPR/first-alert)")
    return 2


if __name__ == "__main__":
    sys.exit(main())
