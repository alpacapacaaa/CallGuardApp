#!/usr/bin/env python3
"""ml/eval/cer.py — STT 한국어 CER 측정 (PRD M6, P2-T5).

Tests/Fixtures/audio/MANIFEST.md의 정답 전사와 Swift TranscribeFixtures CLI가
생성한 실제 전사(wide/narrow8k 두 대역)를 비교해 문자 오류율(CER)을 계산한다.
narrow8k(통화 대역 8kHz 시뮬레이션)는 실행 시점에 인메모리로 다운샘플 —
신규 오디오 파일을 커밋하지 않는다(G5).

exit code: 0 = 측정 완료, 1 = 실행 실패.
외부 의존성 없음(표준 라이브러리만) — G10 대상 아님.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "Tests/Fixtures/audio/MANIFEST.md"
BINARY = ROOT / ".build/debug/TranscribeFixtures"


def load_ground_truth() -> dict:
    truth = {}
    for line in MANIFEST.read_text(encoding="utf-8").splitlines():
        if not line.startswith("| ") or line.startswith("| 파일"):
            continue
        cols = [c.strip() for c in line.strip("|").split("|")]
        if len(cols) < 5 or not cols[0].endswith(".wav"):
            continue
        truth[cols[0]] = cols[3]
    return truth


def cer(reference: str, hypothesis: str) -> float:
    """레벤슈타인 편집거리 기반 CER — 직접 구현(AGENTS.md §8-5, G10)."""
    ref = list(reference.replace(" ", ""))
    hyp = list(hypothesis.replace(" ", ""))
    if not ref:
        return 0.0 if not hyp else 1.0
    prev = list(range(len(hyp) + 1))
    for i, rc in enumerate(ref, start=1):
        cur = [i] + [0] * len(hyp)
        for j, hc in enumerate(hyp, start=1):
            cost = 0 if rc == hc else 1
            cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
        prev = cur
    return prev[len(hyp)] / len(ref)


def main() -> int:
    if not BINARY.exists():
        build = subprocess.run(
            ["swift", "build", "--disable-keychain", "--product", "TranscribeFixtures"], cwd=ROOT
        )
        if build.returncode != 0:
            print("status: FAILED — TranscribeFixtures 빌드 실패")
            return 1

    result = subprocess.run([str(BINARY), *sys.argv[1:]], cwd=ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        print("status: FAILED — TranscribeFixtures 실행 실패")
        print(result.stderr)
        return 1

    truth = load_ground_truth()
    rows = [json.loads(line) for line in result.stdout.splitlines() if line.strip()]
    if not rows:
        print("status: FAILED — 전사 결과 0건")
        return 1

    per_band: dict = {}
    for row in rows:
        ref = truth.get(row["fixture"])
        if ref is None:
            continue
        score = cer(ref, row["transcript"])
        per_band.setdefault(row["band"], []).append(score)
        print(f"{row['fixture']} [{row['band']}] CER={score:.3f}")

    print("---")
    overall = []
    for band, scores in per_band.items():
        avg = sum(scores) / len(scores)
        overall.extend(scores)
        print(f"band={band} n={len(scores)} avg_cer={avg:.3f}")
    print(f"overall avg_cer={sum(overall) / len(overall):.3f}")
    print("status: MEASURED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
