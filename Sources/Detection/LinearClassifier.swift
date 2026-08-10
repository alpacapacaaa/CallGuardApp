import Foundation

/// ml/training/train.py가 export한 TF-IDF+로지스틱회귀 가중치(P3-T4).
public struct LinearClassifierModel: Sendable, Decodable {
    public let vocabulary: [String: Int]
    public let idf: [Double]
    public let weights: [Double]
    public let bias: Double

    public static func load(from url: URL) throws -> LinearClassifierModel {
        try JSONDecoder().decode(LinearClassifierModel.self, from: Data(contentsOf: url))
    }
}

/// Swift 인프로세스 추론(P3-T4). Python train.py의 tfidf_vector()+sigmoid()와
/// 동일 알고리즘 — 외부 ML 런타임 의존 없음(G10 직접구현 원칙).
public struct LinearClassifier: Sendable {
    public let model: LinearClassifierModel

    public init(model: LinearClassifierModel) {
        self.model = model
    }

    /// 0...1 확률 점수.
    public func score(text: String) -> Double {
        let tokens = text.split(separator: " ").map(String.init)
        var vector = [Double](repeating: 0, count: model.vocabulary.count)
        if !tokens.isEmpty {
            for token in tokens {
                if let index = model.vocabulary[token] {
                    vector[index] += 1.0 / Double(tokens.count)
                }
            }
            for index in vector.indices {
                vector[index] *= model.idf[index]
            }
            let norm = vector.reduce(0) { $0 + $1 * $1 }.squareRoot()
            if norm > 0 {
                for index in vector.indices {
                    vector[index] /= norm
                }
            }
        }
        var logit = model.bias
        for index in vector.indices {
            logit += vector[index] * model.weights[index]
        }
        return sigmoid(logit)
    }

    private func sigmoid(_ logit: Double) -> Double {
        if logit < -30 {
            return 0
        }
        if logit > 30 {
            return 1
        }
        return 1.0 / (1.0 + exp(-logit))
    }
}
