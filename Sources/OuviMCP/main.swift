import Foundation
import GRDB
import OuviKit

// ouvi-mcp — MCP stdio server over the local Ouvi knowledge base (read-only).
// Wire: newline-delimited JSON-RPC 2.0 on stdin/stdout.
// `ouvi-mcp --doctor` runs an install self-check instead.

func eprint(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
}

enum DoctorError: Error { case check(String) }

if CommandLine.arguments.contains("--doctor") {
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
        eprint("ouvi doctor: FAILED — \(error)")
        exit(1)
    }
}

// MARK: - MCP server

let database: OuviDatabase
do {
    database = try OuviDatabase.openDefault()
} catch {
    eprint("ouvi-mcp: cannot open database: \(error)")
    exit(1)
}

let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

func speakerNames() -> [String: String] {
    let speakers = (try? database.pool.read { try Speaker.fetchAll($0) }) ?? []
    return Dictionary(uniqueKeysWithValues: speakers.map { ($0.id, $0.name) })
}

func sessionLine(_ s: Session) -> String {
    "\(s.id) | \(dateFormatter.string(from: s.startedAt)) | \(s.title)"
}

func renderTranscript(sessionID: String) -> String {
    let names = speakerNames()
    let segments = (try? database.segments(sessionID: sessionID)) ?? []
    return segments.map { seg in
        let t = String(format: "%02d:%02d", seg.startMs / 60000, (seg.startMs / 1000) % 60)
        let who = seg.channel == .me ? "Me" : (seg.speakerID.flatMap { names[$0] } ?? "Participant")
        return "[\(t)] \(who): \(seg.text)"
    }.joined(separator: "\n")
}

struct ToolDef {
    let name: String
    let description: String
    let schema: [String: Any]
    let run: ([String: Any]) -> String
}

let tools: [ToolDef] = [
    ToolDef(
        name: "list_recent_meetings",
        description: "List the user's most recent recorded meetings (id, date, title).",
        schema: [
            "type": "object",
            "properties": ["limit": ["type": "number", "description": "Max results (default 20)"]],
        ],
        run: { args in
            let limit = (args["limit"] as? NSNumber)?.intValue ?? 20
            let sessions = (try? database.recentSessions(limit: limit)) ?? []
            guard !sessions.isEmpty else { return "No meetings recorded yet." }
            return sessions.map(sessionLine).joined(separator: "\n")
        }),
    ToolDef(
        name: "search_meetings",
        description: "Full-text search across all meeting transcripts. Returns matching excerpts with meeting id and timestamp.",
        schema: [
            "type": "object",
            "properties": ["query": ["type": "string"]],
            "required": ["query"],
        ],
        run: { args in
            guard let query = args["query"] as? String, !query.isEmpty else { return "Missing query." }
            let hits = (try? database.searchSegments(matching: query, limit: 30)) ?? []
            guard !hits.isEmpty else { return "No matches for \"\(query)\"." }
            let sessions = (try? database.pool.read { db in
                try Session.fetchAll(db, keys: Array(Set(hits.map(\.sessionID))))
            }) ?? []
            let titles = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.title) })
            return hits.map { hit in
                let t = String(format: "%02d:%02d", hit.startMs / 60000, (hit.startMs / 1000) % 60)
                return "[\(titles[hit.sessionID] ?? hit.sessionID) @ \(t)] \(hit.text)"
            }.joined(separator: "\n")
        }),
    ToolDef(
        name: "get_transcript",
        description: "Full transcript of one meeting, with timestamps and speakers. Pass the meeting id from list_recent_meetings or search_meetings.",
        schema: [
            "type": "object",
            "properties": ["meeting_id": ["type": "string"]],
            "required": ["meeting_id"],
        ],
        run: { args in
            guard let id = args["meeting_id"] as? String,
                  let session = (try? database.session(id: id)) ?? nil
            else { return "Meeting not found." }
            let transcript = renderTranscript(sessionID: session.id)
            return "# \(session.title)\n\(dateFormatter.string(from: session.startedAt))\n\n\(transcript)"
        }),
    ToolDef(
        name: "get_meeting_summary",
        description: "Structured summary (topics, decisions, action items) of one meeting, when available.",
        schema: [
            "type": "object",
            "properties": ["meeting_id": ["type": "string"]],
            "required": ["meeting_id"],
        ],
        run: { args in
            guard let id = args["meeting_id"] as? String,
                  let session = (try? database.session(id: id)) ?? nil
            else { return "Meeting not found." }
            return session.summaryJSON ?? "No summary generated yet for \"\(session.title)\"."
        }),
    ToolDef(
        name: "list_people",
        description: "Known people from meetings (named speakers).",
        schema: ["type": "object", "properties": [String: Any]()],
        run: { _ in
            let speakers = (try? database.pool.read { try Speaker.fetchAll($0) }) ?? []
            let named = speakers.filter { !$0.name.hasPrefix("Falante ") }
            guard !named.isEmpty else { return "No named people yet." }
            return named.map { "\($0.name)\($0.company.map { " (\($0))" } ?? "")" }.joined(separator: "\n")
        }),
]

func jsonData(_ object: Any) -> Data {
    (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
}

func send(_ object: [String: Any]) {
    var data = jsonData(object)
    data.append(0x0A)
    FileHandle.standardOutput.write(data)
}

func reply(id: Any, result: [String: Any]) {
    send(["jsonrpc": "2.0", "id": id, "result": result])
}

func replyError(id: Any, code: Int, message: String) {
    send(["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]])
}

while let line = readLine(strippingNewline: true) {
    guard !line.isEmpty,
          let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
          let method = object["method"] as? String
    else { continue }
    let id = object["id"]

    switch method {
    case "initialize":
        guard let id else { break }
        reply(id: id, result: [
            "protocolVersion": (object["params"] as? [String: Any])?["protocolVersion"] as? String ?? "2025-06-18",
            "capabilities": ["tools": [String: Any]()],
            "serverInfo": ["name": "ouvi", "version": OuviInfo.version],
        ])
    case "notifications/initialized", "notifications/cancelled":
        break
    case "ping":
        if let id { reply(id: id, result: [:]) }
    case "tools/list":
        guard let id else { break }
        reply(id: id, result: [
            "tools": tools.map {
                ["name": $0.name, "description": $0.description, "inputSchema": $0.schema]
            }
        ])
    case "tools/call":
        guard let id else { break }
        let params = object["params"] as? [String: Any] ?? [:]
        let name = params["name"] as? String ?? ""
        let args = params["arguments"] as? [String: Any] ?? [:]
        if let tool = tools.first(where: { $0.name == name }) {
            let text = tool.run(args)
            reply(id: id, result: [
                "content": [["type": "text", "text": text]],
                "isError": false,
            ])
        } else {
            replyError(id: id, code: -32601, message: "unknown tool \(name)")
        }
    default:
        if let id { replyError(id: id, code: -32601, message: "method not supported: \(method)") }
    }
}
