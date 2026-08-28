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

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
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
        if firstBufferHostTime == nil, time.pointee.mFlags.contains(.hostTimeValid) {
            firstBufferHostTime = time.pointee.mHostTime
        }
        let ablPointer = UnsafeMutablePointer(mutating: bufferList)
        guard let frames = ablPointer.pointee.mBuffers.mDataByteSize as UInt32?,
              frames > 0,
              let pcm = AVAudioPCMBuffer(pcmFormat: tapFormat, bufferListNoCopy: ablPointer)
        else { return }

        // Level + silent-denial detection on channel 0.
        if let data = pcm.floatChannelData?[0] {
            let n = Int(pcm.frameLength)
            var sum: Float = 0
            var i = 0
            while i < n {
                let v = data[i]
                sum += v * v
                i += 64
            }
            let rms = n > 0 ? (sum / Float(max(1, n / 64))).squareRoot() : 0
            currentLevel = rms
            if rms > 0.0002 { observedSignal = true }
        }

        do {
            try file.write(from: pcm)
        } catch {
            log.error("tap write failed: \(error.localizedDescription)")
        }
        onBuffer?(pcm)
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
