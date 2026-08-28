import Foundation
import FluidAudio
import OSLog

/// Post-meeting diarization of the system-audio channel, plus cross-meeting
/// speaker re-identification against enrolled voice centroids (all local).
public actor DiarizationService {
    public static let shared = DiarizationService()

    private let log = Logger(subsystem: "com.rafacarloss.ouvi", category: "Diarization")
    private var manager: OfflineDiarizerManager?

    public init() {}

    private func diarizer() async throws -> OfflineDiarizerManager {
        if let manager { return manager }
        let m = OfflineDiarizerManager()
        try await m.prepareModels()
        manager = m
        return m
    }

    public struct SpeakerTurn {
        public let clusterID: String
        public let startMs: Int
        public let endMs: Int
        public let embedding: [Float]
    }

    public func diarize(url: URL) async throws -> [SpeakerTurn] {
        let diarizer = try await diarizer()
        let result = try await diarizer.process(url)
        return result.segments.map {
            SpeakerTurn(
                clusterID: $0.speakerId,
                startMs: Int($0.startTimeSeconds * 1000),
                endMs: Int($0.endTimeSeconds * 1000),
                embedding: $0.embedding)
        }
    }

    // MARK: - Speaker re-identification

    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let denom = (na.squareRoot() * nb.squareRoot())
        return denom > 0 ? dot / denom : 0
    }

    /// Average embedding per diarization cluster for this meeting.
    public static func clusterCentroids(from turns: [SpeakerTurn]) -> [String: [Float]] {
        var sums: [String: [Float]] = [:]
        var counts: [String: Int] = [:]
        for turn in turns where !turn.embedding.isEmpty {
            if var sum = sums[turn.clusterID] {
                for i in 0..<min(sum.count, turn.embedding.count) { sum[i] += turn.embedding[i] }
                sums[turn.clusterID] = sum
                counts[turn.clusterID, default: 0] += 1
            } else {
                sums[turn.clusterID] = turn.embedding
                counts[turn.clusterID] = 1
            }
        }
        return sums.reduce(into: [String: [Float]]()) { acc, pair in
            let count = Float(counts[pair.key] ?? 1)
            acc[pair.key] = pair.value.map { $0 / count }
        }
    }

    /// Matches meeting clusters against known speakers. Returns clusterID → Speaker.id
    /// for matches above `threshold` cosine similarity.
    public static func matchClusters(
        centroids: [String: [Float]],
        knownSpeakers: [Speaker],
        threshold: Float = 0.6
    ) -> [String: String] {
        var assignment: [String: String] = [:]
        for (cluster, centroid) in centroids {
            var best: (id: String, score: Float)?
            for speaker in knownSpeakers {
                guard let data = speaker.voiceCentroid else { continue }
                let stored = data.toFloatArray()
                let score = cosineSimilarity(centroid, stored)
                if score >= threshold, score > (best?.score ?? 0) {
                    best = (speaker.id, score)
                }
            }
            if let best { assignment[cluster] = best.id }
        }
        return assignment
    }

    /// Folds a meeting centroid into a speaker's running centroid (incremental mean).
    public static func updatedCentroid(existing: Data?, count: Int, new: [Float]) -> Data {
        guard let existing, count > 0 else { return new.toData() }
        let old = existing.toFloatArray()
        guard old.count == new.count else { return new.toData() }
        let n = Float(count)
        let merged = zip(old, new).map { ($0 * n + $1) / (n + 1) }
        return merged.toData()
    }
}

extension Data {
    func toFloatArray() -> [Float] {
        withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self))
        }
    }
}

extension [Float] {
    func toData() -> Data {
        withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
