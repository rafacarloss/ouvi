import AVFoundation
import Foundation
import FluidAudio
import OSLog

/// Live draft transcription during a recording: one sliding-window streaming
/// ASR engine per channel, fed straight from the capture callbacks. The final
/// two-pass transcription replaces all of this when the meeting ends.
public final class LiveTranscriber: @unchecked Sendable {
    public struct Update: Sendable {
        public let channel: TranscriptSegment.Channel
        public let confirmed: String
        public let volatile: String
    }

    private let log = Logger(subsystem: "com.rafacarloss.ouvi", category: "LiveASR")
    private let micEngine = SlidingWindowAsrManager()
    private let systemEngine = SlidingWindowAsrManager()
    private var tasks: [Task<Void, Never>] = []

    /// Delivered on the main actor.
    public var onUpdate: (@MainActor (Update) -> Void)?

    public init() {}

    public func start() async throws {
        let models = try await AsrModels.downloadAndLoad(version: .v3)
        try await micEngine.loadModels(models)
        try await systemEngine.loadModels(models)
        try await micEngine.startStreaming(source: .microphone)
        try await systemEngine.startStreaming(source: .system)

        tasks.append(listen(engine: micEngine, channel: .me))
        tasks.append(listen(engine: systemEngine, channel: .them))
        log.info("live transcription started")
    }

    private func listen(engine: SlidingWindowAsrManager, channel: TranscriptSegment.Channel) -> Task<Void, Never> {
        Task { [weak self] in
            for await _ in await engine.transcriptionUpdates {
                guard let self else { return }
                let confirmed = await engine.confirmedTranscript
                let volatile = await engine.volatileTranscript
                let update = Update(channel: channel, confirmed: confirmed, volatile: volatile)
                await MainActor.run { self.onUpdate?(update) }
            }
        }
    }

    /// Audio-thread entry points; SlidingWindowAsrManager buffers internally.
    public func feedMic(_ buffer: AVAudioPCMBuffer) {
        Task { await micEngine.streamAudio(buffer) }
    }

    public func feedSystem(_ buffer: AVAudioPCMBuffer) {
        Task { await systemEngine.streamAudio(buffer) }
    }

    public func stop() async {
        for task in tasks { task.cancel() }
        tasks.removeAll()
        _ = try? await micEngine.finish()
        _ = try? await systemEngine.finish()
    }
}
