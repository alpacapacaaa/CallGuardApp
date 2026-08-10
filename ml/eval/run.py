#!/usr/bin/env python3
"""ml/eval/run.py — 통화 단위 평가 (PRD §3: M2·M3·M4·M5, first-alert).

구현 단계 (plan.md):
    P3-T1  로더: --dry-run 이 데이터셋 통계(건수/라벨 분포) 출력 [구현 완료]
    P3-T7  평가 하니스: 평가셋 전량 — 통화 단위 Recall/Precision/FPR/first-alert [미구현]
    P3-T8  이터레이션: 재실행마다 지표 변화를 이전 수치와 나란히 기록 [미구현]

현재 데이터셋: Tests/Fixtures/audio/MANIFEST.md의 합성 픽스처만(피싱 5/정상 5).
목표(피싱 ≥50/정상 ≥100)는 금감원 "그놈 목소리" 실데이터 배치가 필요 —
이용조건 확인은 운영자 항목(plan.md P3-T1). 로더는 데이터셋 크기와 무관하게 동작.

exit code: 0 = 성공, 1 = 실패, 2 = NOT_IMPLEMENTED.
G12: 이 스크립트는 평가 수단 — 임계값·평가셋 유리한 수정 금지.
"""

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "Tests/Fixtures/audio/MANIFEST.md"
TARGET_PHISHING = 50
TARGET_NORMAL = 100


def load_dataset() -> list:
    calls = []
    for line in MANIFEST.read_text(encoding="utf-8").splitlines():
        if not line.startswith("| ") or line.startswith("| 파일"):
            continue
        cols = [c.strip() for c in line.strip("|").split("|")]
        if len(cols) < 5 or not cols[0].endswith(".wav"):
            continue
        calls.append({"file": cols[0], "label": cols[1], "category": cols[2], "transcript": cols[3]})
    return calls


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    calls = load_dataset()
    if not calls:
        print("status: FAILED — 데이터셋 0건")
        return 1

    if not args.dry_run:
        print("status: NOT_IMPLEMENTED — 평가 하니스(Recall/Precision/FPR/first-alert)는 P3-T7 범위")
        return 2

    labels: dict = {}
    for call in calls:
        labels[call["label"]] = labels.get(call["label"], 0) + 1

    print(f"total: {len(calls)}")
    for label, count in sorted(labels.items()):
        print(f"  {label}: {count}")

    phishing = labels.get("피싱", 0)
    normal = labels.get("정상", 0)
    if phishing < TARGET_PHISHING or normal < TARGET_NORMAL:
        print(f"NOTE: 목표 미달 — 피싱 {phishing}/{TARGET_PHISHING}, 정상 {normal}/{TARGET_NORMAL}")
        print("실데이터 배치는 운영자 항목(plan.md P3-T1) — 현재는 합성 픽스처만")

    print("status: DRY_RUN_OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
