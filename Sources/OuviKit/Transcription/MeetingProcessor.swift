import Foundation
import GRDB
import OSLog

/// Post-recording pipeline: transcribe both channels, diarize the system
/// channel, re-identify known speakers, persist final segments, archive audio.
public final class MeetingProcessor {
    private let log = Logger(subsystem: "com.rafacarloss.ouvi", category: "MeetingProcessor")
    private let database: OuviDatabase

    public init(database: OuviDatabase) {
        self.database = database
    }

    public struct Progress: Sendable {
        public enum Stage: String, Sendable {
            case transcribingMic, transcribingSystem, diarizing, saving, archiving, done
        }
        public let stage: Stage
    }

    /// Runs the full pipeline. `languageHint` is a BCP-47-ish two-letter code ("pt", "en") or nil for auto.
    public func process(
        session recording: RecordingSession,
        streams: RecordingSession.Streams,
        languageHint: String?,
        onProgress: (@Sendable (Progress) -> Void)? = nil
    ) async throws {
        let sessionID = recording.session.id
        do {
            onProgress?(Progress(stage: .transcribingMic))
            let micTranscript = try await TranscriptionService.shared.transcribe(
                url: streams.micWAV, languageHint: languageHint)

            onProgress?(Progress(stage: .transcribingSystem))
            let systemTranscript = try await TranscriptionService.shared.transcribe(
                url: streams.systemWAV, languageHint: languageHint)

            onProgress?(Progress(stage: .diarizing))
            var turns: [DiarizationService.SpeakerTurn] = []
            if !systemTranscript.words.isEmpty {
                do {
                    turns = try await DiarizationService.shared.diarize(url: streams.systemWAV)
                } catch {
                    log.error("diarization failed (continuing without): \(error.localizedDescription)")
                }
            }

            let knownSpeakers = try await database.pool.read { try Speaker.fetchAll($0) }
            let centroids = DiarizationService.clusterCentroids(from: turns)
            let matched = DiarizationService.matchClusters(centroids: centroids, knownSpeakers: knownSpeakers)

            // Persist unmatched clusters as new unnamed speakers so the UI can rename them.
            var clusterToSpeakerID = matched
            var newSpeakers: [Speaker] = []
            var unnamedIndex = 1
            for (cluster, centroid) in centroids where matched[cluster] == nil {
                let speaker = Speaker(
                    name: "Falante \(unnamedIndex)",
                    voiceCentroid: centroid.toData(),
                    enrollmentCount: 1)
                newSpeakers.append(speaker)
                clusterToSpeakerID[cluster] = speaker.id
                unnamedIndex += 1
            }
            let speakersToInsert = newSpeakers
            try await database.pool.write { db in
                for speaker in speakersToInsert {
                    try speaker.insert(db)
                }
                // Fold matched centroids into the running voice profile.
                for (cluster, speakerID) in matched {
                    guard var speaker = try Speaker.fetchOne(db, key: speakerID),
                          let centroid = centroids[cluster] else { continue }
                    speaker.voiceCentroid = DiarizationService.updatedCentroid(
                        existing: speaker.voiceCentroid,
                        count: speaker.enrollmentCount,
                        new: centroid)
                    speaker.enrollmentCount += 1
                    try speaker.update(db)
                }
            }

            onProgress?(Progress(stage: .saving))
            var segments: [TranscriptSegment] = []
            for utterance in micTranscript.utterances {
                segments.append(Self.segment(from: utterance, sessionID: sessionID, channel: .me, speakerID: nil))
            }
            for utterance in systemTranscript.utterances {
                let speakerID = Self.dominantSpeaker(for: utterance, turns: turns)
                    .flatMap { clusterToSpeakerID[$0] }
                segments.append(Self.segment(from: utterance, sessionID: sessionID, channel: .them, speakerID: speakerID))
            }
            segments.sort { $0.startMs < $1.startMs }

            let segmentsToInsert = segments
            try await database.pool.write { db in
                // Replace any draft segments from the live pass.
                try TranscriptSegment
                    .filter(Column("session_id") == sessionID)
                    .deleteAll(db)
                for segment in segmentsToInsert {
                    try segment.insert(db)
                }
            }

            onProgress?(Progress(stage: .archiving))
            try await recording.archiveAudio(streams: streams)
            try recording.markReady(language: languageHint)
            await ChunkIndexer(database: database).indexSession(sessionID)
            onProgress?(Progress(stage: .done))
            log.info("session \(sessionID) processed: \(segments.count) segments")
        } catch {
            recording.markFailed()
            throw error
        }
    }

    private static func segment(
        from utterance: TranscriptionService.Utterance,
        sessionID: String,
        channel: TranscriptSegment.Channel,
        speakerID: String?
    ) -> TranscriptSegment {
        let words = utterance.words.map { ["w": $0.word, "s": Int($0.startTime * 1000), "e": Int($0.endTime * 1000)] as [String: Any] }
        let wordsJSON = (try? JSONSerialization.data(withJSONObject: words)).flatMap { String(data: $0, encoding: .utf8) }
        return TranscriptSegment(
            sessionID: sessionID,
            startMs: utterance.startMs,
            endMs: utterance.endMs,
            channel: channel,
            speakerID: speakerID,
            text: utterance.text,
            wordsJSON: wordsJSON)
    }

    /// The diarization cluster with the largest time overlap with this utterance.
    static func dominantSpeaker(
        for utterance: TranscriptionService.Utterance,
        turns: [DiarizationService.SpeakerTurn]
    ) -> String? {
        var overlap: [String: Int] = [:]
        for turn in turns {
            let start = max(turn.startMs, utterance.startMs)
            let end = min(turn.endMs, utterance.endMs)
            if end > start {
                overlap[turn.clusterID, default: 0] += end - start
            }
        }
        return overlap.max(by: { $0.value < $1.value })?.key
    }
}
