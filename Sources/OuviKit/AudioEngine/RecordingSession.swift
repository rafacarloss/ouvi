import Foundation
import AVFoundation
import OSLog

/// Orchestrates one recording: both capture streams, the session row, files on
/// disk, and the post-stop archival transcode. Mic and system audio stay in
/// separate files forever — that separation is what gives us free "me vs them"
/// attribution and clean diarization input.
public final class RecordingSession {
    public struct Streams {
        public let micWAV: URL
        public let systemWAV: URL
        public let micStartHostTime: UInt64?
        public let systemStartHostTime: UInt64?
    }

    private let log = Logger(subsystem: "com.rafacarloss.ouvi", category: "RecordingSession")
    private let database: OuviDatabase
    private let mic = MicRecorder()
    private let systemTap = SystemAudioTapRecorder()

    public private(set) var session: Session
    public private(set) var startedAt: Date?

    public var micLevel: Float { mic.currentLevel }
    public var systemLevel: Float { systemTap.currentLevel }

    /// Live-transcription taps (set before `start()`); called on audio threads.
    public var onMicBuffer: ((AVAudioPCMBuffer) -> Void)? {
        get { mic.onBuffer }
        set { mic.onBuffer = newValue }
    }
    public var onSystemBuffer: ((AVAudioPCMBuffer) -> Void)? {
        get { systemTap.onBuffer }
        set { systemTap.onBuffer = newValue }
    }
    /// False after a while indicates a silently denied system-audio permission.
    public var systemSignalObserved: Bool { systemTap.observedSignal }
    public var systemDiagnostics: String { systemTap.diagnostics }

    public init(database: OuviDatabase, title: String, kind: Session.Kind = .meeting, calendarEventID: String? = nil) {
        self.database = database
        self.session = Session(kind: kind, title: title, calendarEventID: calendarEventID)
    }

    public func start() throws {
        try OuviPaths.ensureDirectoriesExist()
        let scratch = OuviPaths.recordingsScratch
        let micURL = scratch.appendingPathComponent("\(session.id)-mic.wav")
        let sysURL = scratch.appendingPathComponent("\(session.id)-sys.wav")

        try systemTap.start(writingTo: sysURL)
        do {
            try mic.start(writingTo: micURL)
        } catch {
            systemTap.stop()
            throw error
        }

        startedAt = Date()
        session.startedAt = startedAt!
        session.state = .recording
        session.micAudioPath = micURL.path
        session.systemAudioPath = sysURL.path
        try database.pool.write { [session] db in try session.save(db) }
        log.info("recording started: \(self.session.id)")
    }

    /// Stops capture and returns the raw streams for transcription.
    public func stop() throws -> Streams {
        mic.stop()
        systemTap.stop()
        session.endedAt = Date()
        session.state = .transcribing
        try database.pool.write { [session] db in try session.save(db) }
        guard let micURL = mic.outputURL, let sysURL = systemTap.outputURL else {
            throw OuviAudioError.osStatus("missing recording files", -1)
        }
        return Streams(
            micWAV: micURL,
            systemWAV: sysURL,
            micStartHostTime: mic.firstBufferHostTime,
            systemStartHostTime: systemTap.firstBufferHostTime)
    }

    /// Archives both WAVs as compact .m4a and deletes the scratch files.
    /// Call after the final transcription pass has consumed the WAVs.
    public func archiveAudio(streams: Streams) async throws {
        let audioDir = OuviPaths.audioDirectory
        let micM4A = audioDir.appendingPathComponent("\(session.id)-mic.m4a")
        let sysM4A = audioDir.appendingPathComponent("\(session.id)-sys.m4a")
        try await AudioTranscoder.transcodeToM4A(wav: streams.micWAV, to: micM4A)
        try await AudioTranscoder.transcodeToM4A(wav: streams.systemWAV, to: sysM4A)
        try? FileManager.default.removeItem(at: streams.micWAV)
        try? FileManager.default.removeItem(at: streams.systemWAV)
        session.micAudioPath = micM4A.path
        session.systemAudioPath = sysM4A.path
        try await database.pool.write { [session] db in try session.save(db) }
    }

    public func markReady(language: String?) throws {
        session.state = .ready
        session.language = language
        try database.pool.write { [session] db in try session.save(db) }
    }

    public func markFailed() {
        session.state = .failed
        try? database.pool.write { [session] db in try session.save(db) }
    }
}
