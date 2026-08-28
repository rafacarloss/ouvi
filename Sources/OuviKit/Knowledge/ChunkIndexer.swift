import Foundation
import GRDB
import OSLog

/// Builds RAG chunks (with embeddings when a local embedding endpoint exists)
/// from a session's final transcript. Chunks group consecutive segments up to
/// ~1200 characters so retrieval returns coherent passages, not single lines.
public final class ChunkIndexer {
    private let log = Logger(subsystem: "com.rafacarloss.ouvi", category: "Indexer")
    private let database: OuviDatabase
    private let maxChunkChars = 1200

    public init(database: OuviDatabase) {
        self.database = database
    }

    /// Best-effort: FTS5 already covers keyword search, so embedding failures
    /// (no Ollama running, no model pulled) only cost semantic search.
    public func indexSession(_ sessionID: String) async {
        do {
            let segments = try database.segments(sessionID: sessionID)
            guard !segments.isEmpty else { return }

            // Drop stale chunks for this session (re-index safe).
            try await database.pool.write { db in
                let ids = try Int64.fetchAll(
                    db, sql: "SELECT id FROM chunk WHERE session_id = ?", arguments: [sessionID])
                for id in ids {
                    try db.execute(sql: "DELETE FROM chunk_vec WHERE rowid = ?", arguments: [id])
                }
                try db.execute(sql: "DELETE FROM chunk WHERE session_id = ?", arguments: [sessionID])
            }

            var chunks: [Chunk] = []
            var text = ""
            var startMs: Int?
            var endMs = 0
            func flush() {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    chunks.append(Chunk(sessionID: sessionID, startMs: startMs, endMs: endMs, text: trimmed))
                }
                text = ""
                startMs = nil
            }
            for segment in segments {
                if startMs == nil { startMs = segment.startMs }
                text += segment.text + "\n"
                endMs = segment.endMs
                if text.count >= maxChunkChars { flush() }
            }
            flush()
            guard !chunks.isEmpty else { return }

            let provider = LocalEmbeddingProvider()
            do {
                let embeddings = try await provider.embed(chunks.map(\.text))
                guard embeddings.count == chunks.count else { throw LLMError.emptyResponse }
                for (chunk, embedding) in zip(chunks, embeddings) {
                    try database.insertChunk(chunk, embedding: embedding)
                }
                log.info("indexed \(chunks.count) chunks with embeddings for \(sessionID)")
            } catch {
                // Store chunks without vectors — keyword retrieval still works,
                // and a later re-index can add embeddings.
                let chunksToInsert = chunks
                try await database.pool.write { db in
                    for var chunk in chunksToInsert { try chunk.insert(db) }
                }
                log.info("indexed \(chunks.count) chunks without embeddings (\(error.localizedDescription))")
            }
        } catch {
            log.error("chunk indexing failed for \(sessionID): \(error.localizedDescription)")
        }
    }

    /// Rebuilds chunks for every ready session (used by `ouvi-cli reindex`).
    public func reindexAll() async {
        let sessions = (try? database.recentSessions(limit: 100_000)) ?? []
        for session in sessions where session.state == .ready {
            await indexSession(session.id)
        }
    }
}
