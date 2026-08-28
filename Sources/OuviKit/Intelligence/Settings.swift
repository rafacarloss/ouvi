import Foundation

/// User-facing configuration, UserDefaults-backed (secrets go to Keychain).
public enum OuviSettings {
    private static let defaults = UserDefaults.standard

    public static var vaultPath: String {
        get { defaults.string(forKey: "vaultPath") ?? OuviPaths.defaultVault.path }
        set { defaults.set(newValue, forKey: "vaultPath") }
    }

    public static var vaultURL: URL { URL(fileURLWithPath: vaultPath, isDirectory: true) }

    /// Master switch: when false, no network calls are ever made for AI features.
    public static var cloudEnabled: Bool {
        get { defaults.bool(forKey: "cloudEnabled") }
        set { defaults.set(newValue, forKey: "cloudEnabled") }
    }

    /// Claude model for summaries/chat. The user asked for the most capable results.
    public static var claudeModel: String {
        get { defaults.string(forKey: "claudeModel") ?? "claude-opus-5" }
        set { defaults.set(newValue, forKey: "claudeModel") }
    }

    /// OpenAI-compatible local endpoint (Ollama: http://localhost:11434/v1).
    public static var localLLMBaseURL: String {
        get { defaults.string(forKey: "localLLMBaseURL") ?? "http://localhost:11434/v1" }
        set { defaults.set(newValue, forKey: "localLLMBaseURL") }
    }

    public static var localLLMModel: String {
        get { defaults.string(forKey: "localLLMModel") ?? "qwen3:4b" }
        set { defaults.set(newValue, forKey: "localLLMModel") }
    }

    /// Embedding model served by the local endpoint; empty disables semantic search.
    public static var localEmbeddingModel: String {
        get { defaults.string(forKey: "localEmbeddingModel") ?? "nomic-embed-text" }
        set { defaults.set(newValue, forKey: "localEmbeddingModel") }
    }

    /// Preferred transcript language hint: "auto", "pt", "en", ...
    public static var languageHint: String {
        get { defaults.string(forKey: "languageHint") ?? "auto" }
        set { defaults.set(newValue, forKey: "languageHint") }
    }

    public static var effectiveLanguageHint: String? {
        let hint = languageHint
        return hint == "auto" ? nil : hint
    }

    /// Keep archived audio after transcription (playback + re-transcription).
    public static var keepAudio: Bool {
        get { defaults.object(forKey: "keepAudio") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "keepAudio") }    }
}
