import Foundation

/// Text embeddings from the local OpenAI-compatible endpoint. Any output
/// dimensionality is truncated (Matryoshka-style) and re-normalized to the
/// fixed 256 dims stored in chunk_vec. When no endpoint is reachable, semantic
/// search simply degrades to FTS5 keyword search.
public struct LocalEmbeddingProvider: Sendable {
    public var baseURL: String
    public var model: String

    public init(
        baseURL: String = OuviSettings.localLLMBaseURL,
        model: String = OuviSettings.localEmbeddingModel
    ) {
        self.baseURL = baseURL
        self.model = model
    }

    public func embed(_ texts: [String]) async throws -> [[Float]] {
        guard !model.isEmpty, let url = URL(string: baseURL + "/embeddings") else {
            throw LLMError.notConfigured("Embedding model not configured")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "input": texts,
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw LLMError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]]
        else { throw LLMError.emptyResponse }

        return items
            .sorted { (($0["index"] as? Int) ?? 0) < (($1["index"] as? Int) ?? 0) }
            .compactMap { item -> [Float]? in
                guard let raw = item["embedding"] as? [Any] else { return nil }
                let vector = raw.compactMap { ($0 as? NSNumber)?.floatValue }
                return Self.truncateAndNormalize(vector, to: EmbeddingConstants.dimensions)
            }
    }

    static func truncateAndNormalize(_ vector: [Float], to dims: Int) -> [Float] {
        var v = Array(vector.prefix(dims))
        if v.count < dims {
            v.append(contentsOf: [Float](repeating: 0, count: dims - v.count))
        }
        let norm = v.map { $0 * $0 }.reduce(0, +).squareRoot()
        guard norm > 0 else { return v }
        return v.map { $0 / norm }
    }
}
