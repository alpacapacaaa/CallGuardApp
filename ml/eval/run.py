#!/usr/bin/env python3
"""ml/eval/run.py — 통화 단위 평가 (PRD §3: M2·M3·M4·M5, first-alert).

구현 단계 (plan.md):
    P3-T1  로더: --dry-run 이 데이터셋 통계(건수/라벨 분포) 출력 [구현 완료]
    P3-T7  평가 하니스: 평가셋 전량 — 통화 단위 Recall/Precision/FPR/first-alert [구현 완료]
    P3-T8  이터레이션: 재실행마다 지표 변화를 이전 수치와 나란히 기록 [미구현]

현재 데이터셋: Tests/Fixtures/audio/MANIFEST.md의 합성 픽스처만(피싱 5/정상 5).
목표(피싱 ≥50/정상 ≥100)는 금감원 "그놈 목소리" 실데이터 배치가 필요 —
이용조건 확인은 운영자 항목(plan.md P3-T1). 하니스는 데이터셋 크기와 무관하게 동작
(현재 규모는 G-3 게이트 판정에 불충분 — 실데이터 확보 후 재실행 필요).

exit code: 0 = 성공, 1 = 실패, 2 = NOT_IMPLEMENTED.
G12: 이 스크립트는 평가 수단 — 임계값·평가셋 유리한 수정 금지.
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BINARY = ROOT / ".build/debug/EvaluateDetection"
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


def run_full_evaluation(calls: list) -> int:
    truth = {c["file"]: c["label"] for c in calls}

    if not BINARY.exists():
        build = subprocess.run(
            ["swift", "build", "--disable-keychain", "--product", "EvaluateDetection"], cwd=ROOT
        )
        if build.returncode != 0:
            print("status: FAILED — EvaluateDetection 빌드 실패")
            return 1

    result = subprocess.run([str(BINARY)], cwd=ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        print("status: FAILED — EvaluateDetection 실행 실패")
        print(result.stderr[-2000:])
        return 1

    rows = [json.loads(line) for line in result.stdout.splitlines() if line.strip()]
    if not rows:
        print("status: FAILED — 평가 결과 0건")
        return 1

    tp = fp = fn = tn = 0
    first_alert_times = []
    for row in rows:
        label = truth.get(row["fixture"])
        if label is None:
            continue
        is_phishing = label == "피싱"
        predicted = row["predicted_phishing"]
        if is_phishing and predicted:
            tp += 1
            if row["first_alert_s"] is not None:
                first_alert_times.append(row["first_alert_s"])
        elif is_phishing and not predicted:
            fn += 1
        elif not is_phishing and predicted:
            fp += 1
        else:
            tn += 1

    recall = tp / (tp + fn) if (tp + fn) else 0.0
    precision = tp / (tp + fp) if (tp + fp) else 0.0
    fpr = fp / (fp + tn) if (fp + tn) else 0.0
    avg_first_alert = sum(first_alert_times) / len(first_alert_times) if first_alert_times else None

    print(f"n={len(rows)} tp={tp} fp={fp} fn={fn} tn={tn}")
    print(f"recall={recall:.3f}")
    print(f"precision={precision:.3f}")
    print(f"fpr={fpr:.3f}")
    print(f"first_alert_avg_s={avg_first_alert if avg_first_alert is not None else 'n/a'}")
    if fn:
        missed = [r["fixture"] for r in rows if truth.get(r["fixture"]) == "피싱" and not r["predicted_phishing"]]
        print(f"missed_phishing: {missed}")
    print("NOTE: 현재 10건(피싱5/정상5) 스모크 규모 — G-3 게이트 목표(50/100)에 불충분, 참고용 수치")
    print("status: EVALUATED")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    calls = load_dataset()
    if not calls:
        print("status: FAILED — 데이터셋 0건")
        return 1

    if not args.dry_run:
        return run_full_evaluation(calls)

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
