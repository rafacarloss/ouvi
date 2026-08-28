import Foundation
import GRDB
import CSQLiteVec

/// Owns the GRDB pool, migrations, FTS5 index and the sqlite-vec virtual tables.
public final class OuviDatabase: Sendable {
    public let pool: DatabasePool

    public init(url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var config = Configuration()
        config.foreignKeysEnabled = true
        // Apple's system SQLite has no process-global auto extensions;
        // sqlite-vec must be registered on every connection GRDB opens.
        config.prepareDatabase { db in
            let rc = cs_sqlite_vec_connection_init(UnsafeMutableRawPointer(db.sqliteConnection))
            guard rc == 0 /* SQLITE_OK */ else {
                throw DatabaseError(resultCode: ResultCode(rawValue: rc), message: "sqlite-vec init failed")
            }
        }
        pool = try DatabasePool(path: url.path, configuration: config)
        try Self.migrator.migrate(pool)
    }

    public static func openDefault() throws -> OuviDatabase {
        try OuviDatabase(url: OuviPaths.databaseURL)
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "session") { t in
                t.primaryKey("id", .text)
                t.column("kind", .text).notNull()
                t.column("state", .text).notNull()
                t.column("title", .text).notNull()
                t.column("startedAt", .datetime).notNull()
                t.column("endedAt", .datetime)
                t.column("calendarEventID", .text)
                t.column("micAudioPath", .text)
                t.column("systemAudioPath", .text)
                t.column("notePath", .text)
                t.column("language", .text)
                t.column("summaryJSON", .text)
                t.column("usedCloud", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("deletedAt", .datetime)
            }

            try db.create(table: "speaker") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("company", .text)
                t.column("voice_centroid", .blob)
                t.column("enrollment_count", .integer).notNull().defaults(to: 0)
                t.column("created_at", .datetime).notNull()
            }

            try db.create(table: "segment") { t in
                t.primaryKey("id", .text)
                t.column("session_id", .text).notNull()
                    .indexed().references("session", onDelete: .cascade)
                t.column("start_ms", .integer).notNull()
                t.column("end_ms", .integer).notNull()
                t.column("channel", .text).notNull()
                t.column("speaker_id", .text).references("speaker", onDelete: .setNull)
                t.column("text", .text).notNull()
                t.column("words_json", .text)
                t.column("is_draft", .boolean).notNull().defaults(to: false)
            }

            try db.create(table: "chunk") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("session_id", .text).notNull()
                    .indexed().references("session", onDelete: .cascade)
                t.column("start_ms", .integer)
                t.column("end_ms", .integer)
                t.column("text", .text).notNull()
            }

            try db.create(table: "dictionary_entry") { t in
                t.primaryKey("id", .text)
                t.column("phrase", .text).notNull().unique()
                t.column("replacement", .text)
                t.column("created_at", .datetime).notNull()
            }

            // Full-text index over segments (external content).
            try db.create(virtualTable: "segment_fts", using: FTS5()) { t in
                t.synchronize(withTable: "segment")
                t.tokenizer = .unicode61(diacritics: .removeLegacy)
                t.column("text")
            }
        }

        migrator.registerMigration("v1-vec") { db in
            let dims = EmbeddingConstants.dimensions
            try db.execute(sql: """
                CREATE VIRTUAL TABLE chunk_vec USING vec0(
                    embedding float[\(dims)]
                )
                """)
        }

        return migrator
    }
}

public enum EmbeddingConstants {
    /// Embedding dimensionality stored in chunk_vec. Matryoshka truncation of the
    /// configured embedding model keeps storage small with negligible recall loss.
    public static let dimensions = 256
}

// MARK: - Convenience queries

extension OuviDatabase {
    public func recentSessions(limit: Int = 100) throws -> [Session] {
        try pool.read { db in
            try Session
                .filter(Column("deletedAt") == nil)
                .order(Column("startedAt").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func session(id: String) throws -> Session? {
        try pool.read { db in try Session.fetchOne(db, key: id) }
    }

    public func segments(sessionID: String, includeDrafts: Bool = false) throws -> [TranscriptSegment] {
        try pool.read { db in
            var request = TranscriptSegment
                .filter(Column("session_id") == sessionID)
                .order(Column("start_ms"))
            if !includeDrafts {
                request = request.filter(Column("is_draft") == false)
            }
            return try request.fetchAll(db)
        }
    }

    /// Keyword search over final transcript segments.
    public func searchSegments(matching query: String, limit: Int = 50) throws -> [TranscriptSegment] {
        try pool.read { db in
            let pattern = FTS5Pattern(matchingAnyTokenIn: query)
            guard let pattern else { return [] }
            return try TranscriptSegment.fetchAll(
                db,
                sql: """
                    SELECT segment.* FROM segment
                    JOIN segment_fts ON segment_fts.rowid = segment.rowid
                    WHERE segment_fts MATCH ?
                    ORDER BY bm25(segment_fts)
                    LIMIT ?
                    """,
                arguments: [pattern, limit])
        }
    }

    /// Stores a chunk and its embedding (already truncated/normalized to `EmbeddingConstants.dimensions`).
    public func insertChunk(_ chunk: Chunk, embedding: [Float]) throws {
        precondition(embedding.count == EmbeddingConstants.dimensions)
        try pool.write { db in
            var chunk = chunk
            try chunk.insert(db)
            let blob = embedding.withUnsafeBufferPointer { Data(buffer: $0) }
            try db.execute(
                sql: "INSERT INTO chunk_vec(rowid, embedding) VALUES (?, ?)",
                arguments: [chunk.id, blob])
        }
    }

    /// Nearest-neighbor semantic search; returns chunks with their distance.
    public func semanticSearch(embedding: [Float], limit: Int = 12) throws -> [(chunk: Chunk, distance: Double)] {
        precondition(embedding.count == EmbeddingConstants.dimensions)
        let blob = embedding.withUnsafeBufferPointer { Data(buffer: $0) }
        return try pool.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT chunk.*, v.distance AS distance
                    FROM chunk_vec v
                    JOIN chunk ON chunk.id = v.rowid
                    WHERE v.embedding MATCH ? AND v.k = ?
                    ORDER BY v.distance
                    """,
                arguments: [blob, limit])
            return try rows.map { row in
                (try Chunk(row: row), row["distance"] as Double? ?? .infinity)
            }
        }
    }
}
