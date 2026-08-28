import Foundation
import GRDB
import OSLog

/// The product AI layer: title, structured summary, note enhancement, chat.
/// All prompts are language-following (they answer in the meeting's language).
public struct MeetingSummary: Codable, Sendable {
    public var title: String
    public var overview: String
    public var topics: [Topic]
    public var decisions: [String]
    public var actionItems: [ActionItem]

    public struct Topic: Codable, Sendable {
        public var heading: String
        public var bullets: [String]
    }

    public struct ActionItem: Codable, Sendable {
        public var owner: String?
        public var text: String
    }
}

public final class MeetingIntelligence {
    private let log = Logger(subsystem: "com.rafacarloss.ouvi", category: "Intelligence")
    private let database: OuviDatabase

    public init(database: OuviDatabase) {
        self.database = database
    }

    // MARK: Transcript rendering

    /// Renders the transcript with timestamps and speaker names for prompting.
    public func renderTranscript(sessionID: String) throws -> String {
        let segments = try database.segments(sessionID: sessionID)
        let speakers = try database.pool.read { try Speaker.fetchAll($0) }
        let names = Dictionary(uniqueKeysWithValues: speakers.map { ($0.id, $0.name) })
        return segments.map { segment in
            let t = String(format: "%02d:%02d", segment.startMs / 60000, (segment.startMs / 1000) % 60)
            let who: String
            switch segment.channel {
            case .me: who = "Eu"
            case .them: who = segment.speakerID.flatMap { names[$0] } ?? "Participante"
            }
            return "[\(t)] \(who): \(segment.text)"
        }.joined(separator: "\n")
    }

    // MARK: Summarize

    public func summarize(sessionID: String, userNotes: String?, preferCloud: Bool? = nil) async throws -> MeetingSummary {
        let transcript = try renderTranscript(sessionID: sessionID)
        guard !transcript.isEmpty else { throw LLMError.emptyResponse }
        let backend = LLMRouter.backend(preferCloud: preferCloud)

        let system = """
        You are the summarization engine of Ouvi, a private meeting-notes app. \
        You produce faithful, concise meeting summaries in THE SAME LANGUAGE as the transcript \
        (if the meeting is in Brazilian Portuguese, answer in Brazilian Portuguese). \
        Never invent facts that are not in the transcript. \
        Respond ONLY with a JSON object, no markdown fences, matching exactly this schema:
        {"title": string, "overview": string (2-3 sentences), \
        "topics": [{"heading": string, "bullets": [string]}], \
        "decisions": [string], "actionItems": [{"owner": string|null, "text": string}]}
        """

        var user = "Transcript with timestamps:\n\n\(transcript)"
        if let userNotes, !userNotes.isEmpty {
            user += "\n\nThe user's own rough notes during the meeting (treat these as the most important signals of what mattered):\n\(userNotes)"
        }

        let raw = try await backend.complete(
            system: system,
            messages: [LLMMessage(role: "user", content: user)],
            maxTokens: 8192)
        let summary = try Self.decodeSummary(from: raw)
        try await persist(summary: summary, sessionID: sessionID, usedCloud: backend.isCloud)
        return summary
    }

    static func decodeSummary(from raw: String) throws -> MeetingSummary {
        // Tolerate accidental markdown fences or prose around the JSON object.
        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}") else {
            throw LLMError.emptyResponse
        }
        let jsonText = String(raw[start...end])
        return try JSONDecoder().decode(MeetingSummary.self, from: Data(jsonText.utf8))
    }

    private func persist(summary: MeetingSummary, sessionID: String, usedCloud: Bool) async throws {
        let encoded = String(data: try JSONEncoder().encode(summary), encoding: .utf8)
        try await database.pool.write { db in
            guard var session = try Session.fetchOne(db, key: sessionID) else { return }
            session.summaryJSON = encoded
            if session.title.isEmpty || session.title.hasPrefix("Reunião ") || session.title.hasPrefix("Meeting ") {
                session.title = summary.title
            }
            if usedCloud { session.usedCloud = true }
            try session.update(db)
        }
    }

    // MARK: Enhance notes (the Granola flow)

    /// Merges the user's rough bullets with transcript context. The user's own
    /// lines are preserved verbatim; additions are suffixed with a source
    /// timestamp marker like ((mm:ss)) that the UI turns into a jump link.
    public func enhanceNotes(sessionID: String, userNotes: String, preferCloud: Bool? = nil) async throws -> String {
        let transcript = try renderTranscript(sessionID: sessionID)
        let backend = LLMRouter.backend(preferCloud: preferCloud)
        let system = """
        You enhance meeting notes. You receive the user's rough notes and the full transcript. \
        Rules: (1) Keep every line the user wrote, verbatim, in its original order. \
        (2) Under or between them, add concise bullets that complete what the user flagged, \
        using only transcript facts. (3) Every added bullet MUST end with a transcript \
        timestamp marker in the form ((mm:ss)) pointing to its source. \
        (4) Answer in the language of the notes/transcript. \
        (5) Output plain Markdown, no preamble.
        """
        let user = "User notes:\n\(userNotes)\n\nTranscript:\n\(transcript)"
        let result = try await backend.complete(
            system: system,
            messages: [LLMMessage(role: "user", content: user)],
            maxTokens: 8192)
        if backend.isCloud {
            try await markCloudUsed(sessionID: sessionID)
        }
        return result
    }

    // MARK: Chat with citations

    public func chat(
        sessionID: String?,
        question: String,
        history: [LLMMessage] = [],
        preferCloud: Bool? = nil
    ) async throws -> String {
        let backend = LLMRouter.backend(preferCloud: preferCloud)
        let context: String
        if let sessionID {
            context = try renderTranscript(sessionID: sessionID)
        } else {
            context = try crossMeetingContext(for: question)
        }
        let system = """
        You answer questions about the user's own recorded meetings (Ouvi app). \
        Use ONLY the provided context. When you state a fact, cite its source inline \
        as ((session:mm:ss)) using the markers present in the context. \
        If the context doesn't contain the answer, say so plainly. \
        Answer in the user's language.
        """
        var messages = history
        messages.append(LLMMessage(role: "user", content: "Context:\n\(context)\n\nQuestion: \(question)"))
        return try await backend.complete(system: system, messages: messages, maxTokens: 8192)
    }

    /// Hybrid retrieval for cross-meeting chat: FTS5 always; vector search when
    /// a local embedding endpoint is available.
    func crossMeetingContext(for question: String, limit: Int = 24) throws -> String {
        var pieces: [String] = []
        let hits = try database.searchSegments(matching: question, limit: limit)
        let sessions = try database.pool.read { db in
            try Session.fetchAll(db, keys: Array(Set(hits.map(\.sessionID))))
        }
        let titles = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.title) })
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dates = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, dateFormatter.string(from: $0.startedAt)) })
        for hit in hits {
            let t = String(format: "%02d:%02d", hit.startMs / 60000, (hit.startMs / 1000) % 60)
            let title = titles[hit.sessionID] ?? "?"
            let date = dates[hit.sessionID] ?? "?"
            pieces.append("((\(title) — \(date):\(t))) \(hit.text)")
        }
        return pieces.joined(separator: "\n")
    }

    private func markCloudUsed(sessionID: String) async throws {
        try await database.pool.write { db in
            guard var session = try Session.fetchOne(db, key: sessionID) else { return }
            session.usedCloud = true
            try session.update(db)
        }
    }
}
