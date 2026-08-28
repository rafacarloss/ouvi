import Foundation
import OSLog

public struct LLMMessage: Codable, Sendable {
    public let role: String
    public let content: String
    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public protocol LLMBackend: Sendable {
    var displayName: String { get }
    var isCloud: Bool { get }
    func complete(system: String?, messages: [LLMMessage], maxTokens: Int) async throws -> String
}

public enum LLMError: Error, LocalizedError {
    case missingAPIKey
    case http(Int, String)
    case refused(String)
    case emptyResponse
    case notConfigured(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Claude API key not set (add it in Settings)"
        case let .http(code, body): return "LLM HTTP \(code): \(body.prefix(300))"
        case let .refused(reason): return "The model declined this request (\(reason))"
        case .emptyResponse: return "Empty LLM response"
        case let .notConfigured(what): return what
        }
    }
}

// MARK: - Claude (Anthropic Messages API, raw HTTP — no official Swift SDK)

public struct ClaudeBackend: LLMBackend {
    public let displayName = "Claude"
    public let isCloud = true
    public var model: String

    public init(model: String = OuviSettings.claudeModel) {
        self.model = model
    }

    public func complete(system: String?, messages: [LLMMessage], maxTokens: Int = 8192) async throws -> String {
        guard let key = KeychainService.get(KeychainService.claudeAPIKey), !key.isEmpty else {
            throw LLMError.missingAPIKey
        }
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 600
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Adaptive thinking is the default on current models; omit the `thinking`
        // parameter entirely (explicit configs are rejected on some models).
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
        ]
        if let system { body["system"] = system }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw LLMError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.emptyResponse
        }
        if let stopReason = json["stop_reason"] as? String, stopReason == "refusal" {
            let details = (json["stop_details"] as? [String: Any])?["category"] as? String ?? "unspecified"
            throw LLMError.refused(details)
        }
        guard let content = json["content"] as? [[String: Any]] else { throw LLMError.emptyResponse }
        let text = content
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
        guard !text.isEmpty else { throw LLMError.emptyResponse }
        return text
    }
}

// MARK: - Local OpenAI-compatible endpoint (Ollama, LM Studio, llama-server)

public struct LocalLLMBackend: LLMBackend {
    public let displayName = "Local LLM"
    public let isCloud = false
    public var baseURL: String
    public var model: String

    public init(baseURL: String = OuviSettings.localLLMBaseURL, model: String = OuviSettings.localLLMModel) {
        self.baseURL = baseURL
        self.model = model
    }

    public func complete(system: String?, messages: [LLMMessage], maxTokens: Int = 4096) async throws -> String {
        guard let url = URL(string: baseURL + "/chat/completions") else {
            throw LLMError.notConfigured("Invalid local LLM base URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 600
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var chat: [[String: String]] = []
        if let system { chat.append(["role": "system", "content": system]) }
        chat.append(contentsOf: messages.map { ["role": $0.role, "content": $0.content] })
        let body: [String: Any] = [
            "model": model,
            "messages": chat,
            "max_tokens": maxTokens,
            "stream": false,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw LLMError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String, !text.isEmpty
        else { throw LLMError.emptyResponse }
        return text
    }
}

// MARK: - Router

/// Picks the backend according to the privacy setting: cloud only when the user
/// opted in AND a key exists; otherwise the local endpoint.
public enum LLMRouter {
    public static func backend(preferCloud: Bool? = nil) -> LLMBackend {
        let cloudAllowed = preferCloud ?? OuviSettings.cloudEnabled
        if cloudAllowed, KeychainService.get(KeychainService.claudeAPIKey)?.isEmpty == false {
            return ClaudeBackend()
        }
        return LocalLLMBackend()
    }
}
