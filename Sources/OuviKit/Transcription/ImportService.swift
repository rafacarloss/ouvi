import Foundation
import GRDB
import OSLog

/// Imports a pre-recorded audio/video file as a session: transcribe, diarize,
/// re-identify speakers, persist, write the vault note. (Granola can't do this.)
public final class ImportService {
    private let log = Logger(subsystem: "com.rafacarloss.ouvi", category: "Import")
    private let database: OuviDatabase

    public init(database: OuviDatabase) {
        self.database = database
    }

    /// Returns the created session id.
    @discardableResult
    public func importFile(
        at url: URL,
        title: String? = nil,
        languageHint: String?,
        onProgress: (@Sendable (MeetingProcessor.Progress) -> Void)? = nil
    ) async throws -> String {
        try OuviPaths.ensureDirectoriesExist()
        let name = title ?? url.deletingPathExtension().lastPathComponent
        var session = Session(kind: .importedFile, state: .transcribing, title: name)

        // Imported audio is a single mixed channel: everything is "them",
        // diarization runs over the whole file.
        let audioDir = OuviPaths.audioDirectory
        let stored = audioDir.appendingPathComponent("\(session.id)-import.\(url.pathExtension.isEmpty ? "m4a" : url.pathExtension)")
        try FileManager.default.copyItem(at: url, to: stored)
        session.systemAudioPath = stored.path
        try await database.pool.write { [session] db in try session.save(db) }

        do {
            onProgress?(.init(stage: .transcribingSystem))
            let transcript = try await TranscriptionService.shared.transcribe(url: stored, languageHint: languageHint)

            onProgress?(.init(stage: .diarizing))
            var turns: [DiarizationService.SpeakerTurn] = []
            if !transcript.words.isEmpty {
                do {
                    turns = try await DiarizationService.shared.diarize(url: stored)
                } catch {
                    log.error("import diarization failed (continuing): \(error.localizedDescription)")
                }
            }

            let knownSpeakers = try await database.pool.read { try Speaker.fetchAll($0) }
            let centroids = DiarizationService.clusterCentroids(from: turns)
            let matched = DiarizationService.matchClusters(centroids: centroids, knownSpeakers: knownSpeakers)
            var clusterToSpeakerID = matched
            var newSpeakers: [Speaker] = []
            var unnamedIndex = knownSpeakers.filter { $0.name.hasPrefix("Falante ") }.count + 1
            for (cluster, centroid) in centroids where matched[cluster] == nil {
                let speaker = Speaker(
                    name: "Falante \(unnamedIndex)",
                    voiceCentroid: centroid.toData(),
                    enrollmentCount: 1)
                newSpeakers.append(speaker)
                clusterToSpeakerID[cluster] = speaker.id
                unnamedIndex += 1
            }

            onProgress?(.init(stage: .saving))
            var segments: [TranscriptSegment] = []
            for utterance in transcript.utterances {
                let cluster = MeetingProcessor.dominantSpeaker(for: utterance, turns: turns)
                segments.append(TranscriptSegment(
                    sessionID: session.id,
                    startMs: utterance.startMs,
                    endMs: utterance.endMs,
                    channel: .them,
                    speakerID: cluster.flatMap { clusterToSpeakerID[$0] },
                    text: utterance.text))
            }

            let sessionID = session.id
            let speakersToInsert = newSpeakers
            let segmentsToInsert = segments
            try await database.pool.write { db in
                for speaker in speakersToInsert { try speaker.insert(db) }
                for segment in segmentsToInsert { try segment.insert(db) }
                guard var stored = try Session.fetchOne(db, key: sessionID) else { return }
                stored.state = .ready
                stored.endedAt = Date()
                try stored.update(db)
            }

            onProgress?(.init(stage: .archiving))
            let writer = VaultWriter(database: database)
            _ = try? writer.writeNote(sessionID: sessionID, userNotes: nil, enhancedNotes: nil)
            try? writer.writePersonPages()
            await ChunkIndexer(database: database).indexSession(sessionID)

            onProgress?(.init(stage: .done))
            log.info("imported \(url.lastPathComponent): \(segmentsToInsert.count) segments")
            return sessionID
        } catch {
            let sessionID = session.id
            try? await database.pool.write { db in
                guard var stored = try Session.fetchOne(db, key: sessionID) else { return }
                stored.state = .failed
                try stored.update(db)
            }
            throw error
        }
    }
}
