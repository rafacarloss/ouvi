import Foundation
import OuviKit

// ouvi-mcp: MCP stdio server over the local Ouvi knowledge base.
// `ouvi-mcp --doctor` runs an install self-check (database, FTS5, sqlite-vec).

let args = CommandLine.arguments

if args.contains("--doctor") {
    do {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ouvi-doctor-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let db = try OuviDatabase(url: tmp)

        var session = Session(kind: .meeting, title: "doctor")
        session.state = .ready
        try db.pool.write { try session.insert($0) }
        let segment = TranscriptSegment(
            sessionID: session.id, startMs: 0, endMs: 1200, channel: .them,
            text: "reunião de teste sobre transcrição impecável")
        try db.pool.write { try segment.insert($0) }

        let hits = try db.searchSegments(matching: "transcrição")
        guard hits.count == 1 else { throw DoctorError.check("FTS5 search returned \(hits.count) hits") }

        var embedding = [Float](repeating: 0, count: EmbeddingConstants.dimensions)
        embedding[0] = 1
        try db.insertChunk(
            Chunk(sessionID: session.id, startMs: 0, endMs: 1200, text: segment.text),
            embedding: embedding)
        let neighbors = try db.semanticSearch(embedding: embedding, limit: 1)
        guard neighbors.count == 1 else { throw DoctorError.check("vec0 KNN returned \(neighbors.count) rows") }

        print("ouvi doctor: OK (GRDB + FTS5 + sqlite-vec \(EmbeddingConstants.dimensions)d)")
        exit(0)
    } catch {
        FileHandle.standardError.write("ouvi doctor: FAILED — \(error)\n".data(using: .utf8)!)
        exit(1)
    }
}

enum DoctorError: Error { case check(String) }

// MCP server proper is implemented in a later phase.
FileHandle.standardError.write("ouvi-mcp \(OuviInfo.version): MCP server not yet implemented; run with --doctor for a self-check\n".data(using: .utf8)!)
exit(2)
