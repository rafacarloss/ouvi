import Foundation
import CoreAudio
import AVFoundation
import OSLog

/// Captures system audio output ("them") using a Core Audio process tap
/// (macOS 14.4+, AudioCap pattern): CATapDescription → AudioHardwareCreateProcessTap
/// → private aggregate device → raw IOProc. Requires the "System Audio Recording
/// Only" TCC grant (NSAudioCaptureUsageDescription). Denial is silent: the tap
/// delivers zero-filled buffers, which callers can detect via `observedSignal`.
public final class SystemAudioTapRecorder {
    private let log = Logger(subsystem: "com.rafacarloss.ouvi", category: "SystemTap")

    private var tapID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID: AudioObjectID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private var file: AVAudioFile?
    private var tapFormat: AVAudioFormat?

    /// Host time of the first rendered buffer, for wall-clock alignment.
    public private(set) var firstBufferHostTime: UInt64?
    /// Running peak since start; true once any non-silent sample was seen.
    public private(set) var observedSignal = false
    /// Most recent RMS level in 0...1, for UI metering.
    public private(set) var currentLevel: Float = 0

    // Diagnostics (read after stop): what actually happened inside the IOProc.
    public private(set) var callbackCount = 0
    public private(set) var conversionFailures = 0
    public private(set) var writeErrors = 0
    public private(set) var framesWritten: Int64 = 0

    public private(set) var peakAmplitude: Float = 0

    public var diagnostics: String {
        "callbacks=\(callbackCount) frames=\(framesWritten) convFail=\(conversionFailures) writeErr=\(writeErrors) peak=\(peakAmplitude) signal=\(observedSignal)"
    }

    public private(set) var outputURL: URL?

    /// Called on the audio thread with each captured buffer — used to feed the
    /// live streaming transcriber. Keep the work minimal.
    public var onBuffer: ((AVAudioPCMBuffer) -> Void)?

    public init() {}

    public var isRunning: Bool { ioProcID != nil }

    public func start(writingTo url: URL) throws {
        precondition(!isRunning)

        // Global tap: capture everything the user hears. (Excluding our own
        // process would need a PID→AudioObjectID translation; Ouvi plays no
        // sounds while recording, so a plain global tap is fine.)
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.uuid = UUID()
        description.name = "Ouvi system tap"
        description.isPrivate = true

        var newTapID = AudioObjectID(kAudioObjectUnknown)
        var status = AudioHardwareCreateProcessTap(description, &newTapID)
        guard status == noErr else {
            throw OuviAudioError.osStatus("AudioHardwareCreateProcessTap", status)
        }
        tapID = newTapID

        // Read the tap's stream format (can differ per output device; may change on route change).
        var asbd = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        status = AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &asbd)
        guard status == noErr, let format = AVAudioFormat(streamDescription: &asbd) else {
            cleanup()
            throw OuviAudioError.osStatus("kAudioTapPropertyFormat", status)
        }
        tapFormat = format

        // Build a private aggregate device containing only the tap.
        let systemOutputUID = try Self.defaultOutputDeviceUID()
        let aggregateUID = UUID().uuidString
        let composition: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: "Ouvi tap aggregate",
            kAudioAggregateDeviceUIDKey as String: aggregateUID,
            kAudioAggregateDeviceIsPrivateKey as String: true,
            kAudioAggregateDeviceIsStackedKey as String: false,
            kAudioAggregateDeviceMainSubDeviceKey as String: systemOutputUID,
            kAudioAggregateDeviceSubDeviceListKey as String: [
                [kAudioSubDeviceUIDKey as String: systemOutputUID]
            ],
            kAudioAggregateDeviceTapListKey as String: [
                [
                    kAudioSubTapDriftCompensationKey as String: true,
                    kAudioSubTapUIDKey as String: description.uuid.uuidString,
                ]
            ],
        ]
        var newAggregateID = AudioObjectID(kAudioObjectUnknown)
        status = AudioHardwareCreateAggregateDevice(composition as CFDictionary, &newAggregateID)
        guard status == noErr else {
            cleanup()
            throw OuviAudioError.osStatus("AudioHardwareCreateAggregateDevice", status)
        }
        aggregateID = newAggregateID

        // The file's processing format must match the tap's buffer layout
        // (interleaved float), or every write(from:) throws a format mismatch.
        let file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved)
        self.file = file
        outputURL = url

        var procID: AudioDeviceIOProcID?
        status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, nil) {
            [weak self] _, inInputData, inInputTime, _, _ in
            self?.render(bufferList: inInputData, time: inInputTime)
        }
        guard status == noErr, let procID else {
            cleanup()
            throw OuviAudioError.osStatus("AudioDeviceCreateIOProcIDWithBlock", status)
        }
        ioProcID = procID

        // The TCC prompt (if any) fires here.
        status = AudioDeviceStart(aggregateID, procID)
        guard status == noErr else {
            cleanup()
            throw OuviAudioError.osStatus("AudioDeviceStart", status)
        }
        log.info("System tap started, format: \(format.sampleRate)Hz \(format.channelCount)ch")
    }

    private func render(bufferList: UnsafePointer<AudioBufferList>, time: UnsafePointer<AudioTimeStamp>) {
        guard let file, let tapFormat else { return }
        callbackCount += 1
        if firstBufferHostTime == nil, time.pointee.mFlags.contains(.hostTimeValid) {
            firstBufferHostTime = time.pointee.mHostTime
        }
        let ablPointer = UnsafeMutablePointer(mutating: bufferList)
        guard ablPointer.pointee.mBuffers.mDataByteSize > 0 else { return }
        guard let pcm = makePCMBuffer(from: ablPointer, format: tapFormat) else {
            conversionFailures += 1
            if conversionFailures == 1 {
                log.error("tap ABL→PCM conversion failed (buffers=\(ablPointer.pointee.mNumberBuffers), bytes=\(ablPointer.pointee.mBuffers.mDataByteSize))")
            }
            return
        }

        // Level + silent-denial detection. floatChannelData is nil for
        // interleaved buffers, so read the raw buffer and stride by channel.
        let frames = Int(pcm.frameLength)
        if frames > 0, let raw = pcm.audioBufferList.pointee.mBuffers.mData {
            let stride = tapFormat.isInterleaved ? Int(tapFormat.channelCount) : 1
            let data = raw.assumingMemoryBound(to: Float.self)
            var sum: Float = 0
            var count = 0
            var i = 0
            while i < frames * stride {
                let v = data[i]
                sum += v * v
                count += 1
                if abs(v) > peakAmplitude { peakAmplitude = abs(v) }
                i += 64 * stride
            }
            let rms = count > 0 ? (sum / Float(count)).squareRoot() : 0
            currentLevel = rms
            if rms > 0.0002 { observedSignal = true }
        }

        do {
            try file.write(from: pcm)
            framesWritten += Int64(pcm.frameLength)
        } catch {
            writeErrors += 1
            if writeErrors == 1 {
                log.error("tap write failed: \(error.localizedDescription)")
            }
        }
        onBuffer?(pcm)
    }

    /// Wraps the IOProc's AudioBufferList as an AVAudioPCMBuffer. Tries the
    /// zero-copy wrapper first; falls back to a manual copy when the ABL
    /// layout doesn't match the format's expectation (interleaved vs not).
    private func makePCMBuffer(
        from abl: UnsafeMutablePointer<AudioBufferList>,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        if let pcm = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: abl) {
            return pcm
        }
        // Manual path: compute frames from byte size and copy channel data.
        let buffers = UnsafeMutableAudioBufferListPointer(abl)
        guard let first = buffers.first, let firstData = first.mData else { return nil }
        let bytesPerFrame = Int(format.streamDescription.pointee.mBytesPerFrame)
        guard bytesPerFrame > 0 else { return nil }
        let frames = AVAudioFrameCount(Int(first.mDataByteSize) / bytesPerFrame)
        guard frames > 0, let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            return nil
        }
        pcm.frameLength = frames
        if format.isInterleaved {
            memcpy(pcm.audioBufferList.pointee.mBuffers.mData, firstData, Int(first.mDataByteSize))
        } else if let channelData = pcm.floatChannelData {
            for (index, buffer) in buffers.enumerated() where index < Int(format.channelCount) {
                if let data = buffer.mData {
                    memcpy(channelData[index], data, Int(buffer.mDataByteSize))
                }
            }
        }
        return pcm
    }

    public func stop() {
        if let ioProcID, aggregateID != kAudioObjectUnknown {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
        }
        ioProcID = nil
        cleanup()
        file = nil
    }

    private func cleanup() {
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }

    private static func defaultOutputDeviceUID() throws -> String {
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        guard status == noErr else { throw OuviAudioError.osStatus("DefaultOutputDevice", status) }

        var uid: CFString = "" as CFString
        size = UInt32(MemoryLayout<CFString>.size)
        address.mSelector = kAudioDevicePropertyDeviceUID
        status = withUnsafeMutablePointer(to: &uid) { ptr in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, ptr)
        }
        guard status == noErr else { throw OuviAudioError.osStatus("DeviceUID", status) }
        return uid as String
    }
}

public enum OuviAudioError: Error, LocalizedError {
    case osStatus(String, OSStatus)
    case notAuthorized(String)

    public var errorDescription: String? {
        switch self {
        case let .osStatus(op, code): return "\(op) failed (OSStatus \(code))"
        case let .notAuthorized(what): return "Missing permission: \(what)"
        }
    }
}
