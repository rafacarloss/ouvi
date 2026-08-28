import AppKit
import AVFoundation
import Foundation
import GRDB
import OSLog

/// The Wispr-Flow-style loop: hold key → record → release → transcribe →
/// LLM cleanup (local by default) → paste at the cursor. Transcription and
/// audio never leave the machine; cleanup uses the local endpoint unless the
/// user opted into cloud.
@MainActor
public final class DictationController: ObservableObject {
    public enum State: Equatable {
        case idle
        case recording
        case processing
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var level: Float = 0

    private let log = Logger(subsystem: "com.rafacarloss.ouvi", category: "Dictation")
    private let hotkeys = HotkeyManager()
    private let database: OuviDatabase?
    private var recorder: MicRecorder?
    private var recordingURL: URL?
    private var levelTimer: Timer?

    public var onStateChange: ((State) -> Void)?

    public init(database: OuviDatabase?) {
        self.database = database
    }

    public func start() {
        hotkeys.onToggle = { [weak self] in
            guard let self else { return }
            if self.state == .recording { self.finishRecording() } else if self.state == .idle { self.beginRecording() }
        }
        hotkeys.onPushToTalkDown = { [weak self] in
            guard let self, self.state == .idle else { return }
            // Prewarm the ASR model while the user is still speaking.
            Task.detached { try? await TranscriptionService.shared.warmUp() }
            self.beginRecording()
        }
        hotkeys.onPushToTalkUp = { [weak self] in
            guard let self, self.state == .recording else { return }
            self.finishRecording()
        }
        hotkeys.start()
    }

    public func stop() {
        hotkeys.stop()
    }

    private func beginRecording() {
        guard !CursorPaster.secureInputActive else {
            NSSound.beep()
            return
        }
        do {
            try OuviPaths.ensureDirectoriesExist()
            let url = OuviPaths.recordingsScratch
                .appendingPathComponent("dictation-\(UUID().uuidString).wav")
            let recorder = MicRecorder()
            // No echo cancellation for dictation: lower latency, and there is
            // no far-end signal to cancel.
            try recorder.start(writingTo: url, echoCancellation: false)
            self.recorder = recorder
            self.recordingURL = url
            setState(.recording)
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.level = self.recorder?.currentLevel ?? 0
                }
            }
        } catch {
            log.error("dictation record failed: \(error.localizedDescription)")
            setState(.idle)
        }
    }

    private func finishRecording() {
        guard let recorder, let url = recordingURL else { return }
        recorder.stop()
        self.recorder = nil
        levelTimer?.invalidate()
        levelTimer = nil
        setState(.processing)

        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName ?? "unknown"
        let db = database

        Task {
            defer { try? FileManager.default.removeItem(at: url) }
            do {
                let transcript = try await TranscriptionService.shared.transcribe(
                    url: url, languageHint: OuviSettings.effectiveLanguageHint)
                let raw = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !raw.isEmpty else {
                    await MainActor.run { self.setState(.idle) }
                    return
                }
                let cleaned = await Self.cleanUp(raw, targetApp: appName, database: db)
                await MainActor.run {
                    CursorPaster.paste(cleaned)
                    self.setState(.idle)
                }
            } catch {
                self.log.error("dictation failed: \(error.localizedDescription)")
                await MainActor.run { self.setState(.idle) }
            }
        }
    }

    private func setState(_ new: State) {
        state = new
        onStateChange?(new)
    }

    /// LLM cleanup with graceful degradation: if no LLM is reachable within a
    /// short window, paste the raw ASR text (which already has punctuation).
    static func cleanUp(_ raw: String, targetApp: String, database: OuviDatabase?) async -> String {
        var glossary: [DictionaryEntry] = []
        if let database {
            glossary = (try? await database.pool.read { try DictionaryEntry.fetchAll($0) }) ?? []
        }
        var text = raw
        // Deterministic replacements first — they work even without an LLM.
        for entry in glossary {
            if let replacement = entry.replacement {
                text = text.replacingOccurrences(
                    of: entry.phrase, with: replacement, options: [.caseInsensitive])
            }
        }

        let backend = LLMRouter.backend()
        let protectedTerms = glossary.filter { $0.replacement == nil }.map(\.phrase)
        let system = """
        You clean up dictated text for insertion into another app. \
        Remove filler words and false starts; honor spoken self-corrections \
        (e.g. "quinta, aliás, sexta" → "sexta"); fix punctuation and casing; \
        format lists when the speaker clearly dictates one. \
        Keep the speaker's language and wording otherwise — do NOT rewrite style, \
        do NOT add content, do NOT answer questions in the text. \
        Target application: \(targetApp). \
        \(protectedTerms.isEmpty ? "" : "Spell these terms exactly: \(protectedTerms.joined(separator: ", ")).") \
        Output ONLY the cleaned text.
        """
        do {
            let task = Task {
                try await backend.complete(
                    system: system,
                    messages: [LLMMessage(role: "user", content: text)],
                    maxTokens: 2048)
            }
            let timeout = Task {
                try await Task.sleep(nanoseconds: 8_000_000_000)
                task.cancel()
            }
            let cleaned = try await task.value
            timeout.cancel()
            let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? text : trimmed
        } catch {
            return text
        }
    }
}
