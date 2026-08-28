import Foundation
import AVFoundation
import OSLog

/// Records the microphone ("me") through AVAudioEngine with voice processing
/// (echo cancellation) enabled, so the user's speakers don't leak remote voices
/// into the mic channel. Ducking is disabled — otherwise macOS attenuates the
/// system-audio capture to near-silence while VPIO is active.
public final class MicRecorder {
    private let log = Logger(subsystem: "com.rafacarloss.ouvi", category: "Mic")
    private let engine = AVAudioEngine()
    private var file: AVAudioFile?

    public private(set) var firstBufferHostTime: UInt64?
    public private(set) var currentLevel: Float = 0
    public private(set) var outputURL: URL?

    public init() {}

    public var isRunning: Bool { engine.isRunning }

    public func start(writingTo url: URL, echoCancellation: Bool = true) throws {
        precondition(!engine.isRunning)
        let input = engine.inputNode

        if echoCancellation {
            do {
                try input.setVoiceProcessingEnabled(true)
                input.voiceProcessingOtherAudioDuckingConfiguration = .init(
                    enableAdvancedDucking: false, duckingLevel: .min)
            } catch {
                // Some devices refuse VPIO; keep recording without AEC rather than failing.
                log.warning("voice processing unavailable: \(error.localizedDescription)")
            }
        }

        // VPIO can silently change the input format (e.g. mono → multichannel);
        // always read the format after enabling it.
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw OuviAudioError.notAuthorized("microphone (input format unavailable)")
        }

        // Persist channel 0 only: AEC output is effectively mono.
        guard let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: format.sampleRate,
            channels: 1, interleaved: false)
        else { throw OuviAudioError.osStatus("mono format", -1) }

        let file = try AVAudioFile(forWriting: url, settings: monoFormat.settings)
        self.file = file
        outputURL = url

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, when in
            guard let self else { return }
            if self.firstBufferHostTime == nil {
                self.firstBufferHostTime = when.hostTime
            }
            guard let src = buffer.floatChannelData?[0] else { return }
            let frames = Int(buffer.frameLength)

            var sum: Float = 0
            var i = 0
            while i < frames {
                let v = src[i]
                sum += v * v
                i += 64
            }
            self.currentLevel = frames > 0 ? (sum / Float(max(1, frames / 64))).squareRoot() : 0

            guard let out = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: buffer.frameLength)
            else { return }
            out.frameLength = buffer.frameLength
            out.floatChannelData?[0].update(from: src, count: frames)
            do {
                try file.write(from: out)
            } catch {
                self.log.error("mic write failed: \(error.localizedDescription)")
            }
        }

        engine.prepare()
        try engine.start()
        log.info("Mic recording started at \(format.sampleRate)Hz")
    }

    public func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? engine.inputNode.setVoiceProcessingEnabled(false)
        file = nil
    }
}
