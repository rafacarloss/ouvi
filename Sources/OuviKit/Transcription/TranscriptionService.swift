import AVFoundation
import Foundation
import FluidAudio
import OSLog

/// Final-pass transcription: Parakeet TDT v3 (25 languages incl. pt/en) on the
/// Neural Engine via FluidAudio, with per-word timestamps. One call per channel
/// file; utterance segmentation is derived from word-timing gaps.
public actor TranscriptionService {
    public static let shared = TranscriptionService()

    private let log = Logger(subsystem: "com.rafacarloss.ouvi", category: "ASR")
    private var asrManager: AsrManager?

    /// Utterances are split when the gap between consecutive words exceeds this.
    private let utteranceGap: TimeInterval = 1.0
    /// ...or when an utterance would exceed this duration.
    private let maxUtterance: TimeInterval = 25.0

    public init() {}

    public func warmUp() async throws {
        _ = try await manager()
    }

    private func manager() async throws -> AsrManager {
        if let asrManager { return asrManager }
        log.info("loading Parakeet v3 models (downloads on first run)")
        let models = try await AsrModels.downloadAndLoad(version: .v3)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        asrManager = manager
        return manager
    }

    public struct ChannelTranscript {
        public let text: String
        public let words: [WordTiming]
        public let utterances: [Utterance]
    }

    public struct Utterance {
        public let startMs: Int
        public let endMs: Int
        public let text: String
        public let words: [WordTiming]
    }

    /// Transcribes one audio file (any format/sample rate; FluidAudio resamples,
    /// and long files stream from disk with constant memory).
    /// Files shorter than ~0.4s (e.g. an empty channel) return an empty
    /// transcript instead of failing the whole pipeline.
    public func transcribe(url: URL, languageHint: String?) async throws -> ChannelTranscript {
        if let audioFile = try? AVAudioFile(forReading: url) {
            let seconds = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            if seconds < 0.4 {
                log.info("skipping \(url.lastPathComponent): only \(String(format: "%.2f", seconds))s of audio")
                return ChannelTranscript(text: "", words: [], utterances: [])
            }
        }
        let manager = try await manager()
        let language = languageHint.flatMap { Language(rawValue: $0) }
        var state = try TdtDecoderState()
        let result = try await manager.transcribe(url, decoderState: &state, language: language)
        let words = buildWordTimings(from: result.tokenTimings ?? [])
        let utterances = Self.utterances(from: words, gap: utteranceGap, maxLength: maxUtterance)
        log.info("transcribed \(url.lastPathComponent): \(words.count) words, \(utterances.count) utterances, rtfx \(result.rtfx)")
        return ChannelTranscript(text: result.text, words: words, utterances: utterances)
    }

    static func utterances(from words: [WordTiming], gap: TimeInterval, maxLength: TimeInterval) -> [Utterance] {
        guard !words.isEmpty else { return [] }
        var result: [Utterance] = []
        var current: [WordTiming] = []

        func flush() {
            guard let first = current.first, let last = current.last else { return }
            let text = current.map(\.word).joined(separator: " ")
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { current = []; return }
            result.append(Utterance(
                startMs: Int(first.startTime * 1000),
                endMs: Int(last.endTime * 1000),
                text: text,
                words: current))
            current = []
        }

        for word in words {
            if let last = current.last {
                let pause = word.startTime - last.endTime
                let length = word.endTime - (current.first?.startTime ?? word.startTime)
                if pause >= gap || length >= maxLength {
                    flush()
                }
            }
            current.append(word)
        }
        flush()
        return result
    }
}
