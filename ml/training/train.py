#!/usr/bin/env python3
"""ml/training/train.py — 경량 선형 분류기 학습 (P3-T3, 2026-08-10 스코프 변경).

TF-IDF + 로지스틱회귀, 순수 표준 라이브러리(외부 의존성 없음 — G10 비대상,
AGENTS.md §8-5 직접 구현 원칙). 참고 접근: selfcontrol7/Korean_Voice_Phishing_Detection
(MIT, KorCCVi 데이터셋) — 코드는 새로 작성.

현재 데이터: Tests/Fixtures/audio/MANIFEST.md 합성 픽스처 10건뿐(--smoke 전제,
plan.md P3-T1 참조). 실데이터 확보 후 ml/eval/run.py 데이터셋으로 재학습 필요.

exit code: 0 = 성공, 1 = 실패.
"""
import argparse
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "Tests/Fixtures/audio/MANIFEST.md"
MODEL_OUT = Path(__file__).resolve().parent / "model.json"
SCORES_OUT = Path(__file__).resolve().parent / "scores.json"


def load_examples() -> list:
    examples = []
    for line in MANIFEST.read_text(encoding="utf-8").splitlines():
        if not line.startswith("| ") or line.startswith("| 파일"):
            continue
        cols = [c.strip() for c in line.strip("|").split("|")]
        if len(cols) < 5 or not cols[0].endswith(".wav"):
            continue
        label = 1 if cols[1] == "피싱" else 0
        examples.append((cols[3], label))
    return examples


def tokenize(text: str) -> list:
    return text.split()


def build_vocab(texts: list) -> dict:
    vocab: dict = {}
    for text in texts:
        for token in tokenize(text):
            if token not in vocab:
                vocab[token] = len(vocab)
    return vocab


def compute_idf(texts: list, vocab: dict) -> list:
    n = len(texts)
    df = [0] * len(vocab)
    for text in texts:
        for token in set(tokenize(text)):
            if token in vocab:
                df[vocab[token]] += 1
    return [math.log((1 + n) / (1 + d)) + 1 for d in df]


def tfidf_vector(text: str, vocab: dict, idf: list) -> list:
    tokens = tokenize(text)
    vec = [0.0] * len(vocab)
    if not tokens:
        return vec
    for token in tokens:
        if token in vocab:
            vec[vocab[token]] += 1.0 / len(tokens)
    vec = [v * w for v, w in zip(vec, idf)]
    norm = math.sqrt(sum(v * v for v in vec)) or 1.0
    return [v / norm for v in vec]


def sigmoid(z: float) -> float:
    if z < -30:
        return 0.0
    if z > 30:
        return 1.0
    return 1.0 / (1.0 + math.exp(-z))


def train_logreg(features: list, labels: list, epochs: int = 300, lr: float = 0.5):
    n_features = len(features[0]) if features else 0
    weights = [0.0] * n_features
    bias = 0.0
    n = len(features) or 1
    for _ in range(epochs):
        grad_w = [0.0] * n_features
        grad_b = 0.0
        for x, y in zip(features, labels):
            pred = sigmoid(sum(w * xi for w, xi in zip(weights, x)) + bias)
            error = pred - y
            for i, xi in enumerate(x):
                grad_w[i] += error * xi
            grad_b += error
        weights = [w - lr * (g / n) for w, g in zip(weights, grad_w)]
        bias -= lr * (grad_b / n)
    return weights, bias


def predict(weights: list, bias: float, x: list) -> int:
    z = sum(w * xi for w, xi in zip(weights, x)) + bias
    return 1 if sigmoid(z) >= 0.5 else 0


def f1_score(y_true: list, y_pred: list) -> float:
    tp = sum(1 for t, p in zip(y_true, y_pred) if t == 1 and p == 1)
    fp = sum(1 for t, p in zip(y_true, y_pred) if t == 0 and p == 1)
    fn = sum(1 for t, p in zip(y_true, y_pred) if t == 1 and p == 0)
    if tp == 0:
        return 0.0
    precision = tp / (tp + fp) if (tp + fp) else 0.0
    recall = tp / (tp + fn) if (tp + fn) else 0.0
    return 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--smoke", action="store_true")
    args = parser.parse_args()

    examples = load_examples()
    if len(examples) < 4:
        print("status: FAILED — 학습 데이터 부족")
        return 1

    texts = [t for t, _ in examples]
    labels = [label for _, label in examples]

    # 데이터가 10건뿐이라 라벨별 1건씩만 검증으로 남긴다(임시 — 실데이터 확보 후 정식 분할).
    val_idx: list = []
    seen_labels: set = set()
    for i, label in enumerate(labels):
        if label not in seen_labels:
            val_idx.append(i)
            seen_labels.add(label)
    train_idx = [i for i in range(len(examples)) if i not in val_idx]

    train_texts = [texts[i] for i in train_idx]
    vocab = build_vocab(train_texts)
    idf = compute_idf(train_texts, vocab)

    train_features = [tfidf_vector(texts[i], vocab, idf) for i in train_idx]
    train_labels = [labels[i] for i in train_idx]
    weights, bias = train_logreg(train_features, train_labels)

    val_features = [tfidf_vector(texts[i], vocab, idf) for i in val_idx]
    val_labels = [labels[i] for i in val_idx]
    val_preds = [predict(weights, bias, x) for x in val_features]
    f1 = f1_score(val_labels, val_preds)

    print(f"train_n={len(train_idx)} val_n={len(val_idx)}")
    print(f"validation_f1={f1:.3f}")
    if args.smoke:
        print("mode: smoke (데이터 10건 — 실 성능 지표 아님, 실데이터 확보 후 재학습 필요)")

    model = {"vocabulary": vocab, "idf": idf, "weights": weights, "bias": bias}
    MODEL_OUT.write_text(json.dumps(model, ensure_ascii=False), encoding="utf-8")

    # P3-T4 DoD: Swift 추론이 Python과 일치하는지 비교할 기준값 — 전체 예제의 확률 점수.
    all_features = [tfidf_vector(t, vocab, idf) for t in texts]
    scores = {
        text: sigmoid(sum(w * xi for w, xi in zip(weights, x)) + bias)
        for text, x in zip(texts, all_features)
    }
    SCORES_OUT.write_text(json.dumps(scores, ensure_ascii=False), encoding="utf-8")

    print(f"model: {MODEL_OUT}")
    print(f"scores: {SCORES_OUT}")
    print("status: TRAINED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
