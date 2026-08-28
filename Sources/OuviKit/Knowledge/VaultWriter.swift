import Foundation
import GRDB

/// Projects sessions into the user's Markdown vault — plain files, Obsidian
/// compatible, YAML frontmatter, [[wikilinks]] for people. Files over app:
/// the vault plus the audio folder is enough to rebuild the entire index.
public final class VaultWriter {
    private let database: OuviDatabase

    public init(database: OuviDatabase) {
        self.database = database
    }

    /// Writes (or rewrites) the note for a session. Returns the vault-relative path.
    @discardableResult
    public func writeNote(sessionID: String, userNotes: String?, enhancedNotes: String?) throws -> String {
        guard let session = try database.session(id: sessionID) else {
            throw NSError(domain: "Ouvi", code: 404, userInfo: [NSLocalizedDescriptionKey: "session not found"])
        }
        let segments = try database.segments(sessionID: sessionID)
        let speakers = try database.pool.read { try Speaker.fetchAll($0) }
        let names = Dictionary(uniqueKeysWithValues: speakers.map { ($0.id, $0.name) })

        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: session.startedAt)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: session.startedAt)

        let slug = Self.slugify(session.title.isEmpty ? "reuniao" : session.title)
        let relativeDir = String(format: "%04d/%02d", comps.year ?? 0, comps.month ?? 0)
        let relativePath = "\(relativeDir)/\(dateString)-\(slug).md"

        let participants = Set(segments.compactMap { $0.speakerID }.compactMap { names[$0] })
        let summary: MeetingSummary? = session.summaryJSON
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(MeetingSummary.self, from: $0) }

        var md = "---\n"
        md += "title: \"\(Self.yamlEscape(session.title))\"\n"
        md += "date: \(dateString)\n"
        md += "app: ouvi\n"
        md += "session: \(session.id)\n"
        if !participants.isEmpty {
            md += "people:\n"
            for p in participants.sorted() { md += "  - \"[[\(p)]]\"\n" }
        }
        if let lang = session.language { md += "language: \(lang)\n" }
        if let mic = session.micAudioPath { md += "audio_me: \"\(mic)\"\n" }
        if let sys = session.systemAudioPath { md += "audio_them: \"\(sys)\"\n" }
        if session.usedCloud { md += "cloud_ai: true\n" }
        md += "---\n\n"
        md += "# \(session.title)\n\n"

        if let summary {
            md += "\(summary.overview)\n\n"
            for topic in summary.topics {
                md += "## \(topic.heading)\n\n"
                for bullet in topic.bullets { md += "- \(bullet)\n" }
                md += "\n"
            }
            if !summary.decisions.isEmpty {
                md += "## Decisões\n\n"
                for d in summary.decisions { md += "- \(d)\n" }
                md += "\n"
            }
            if !summary.actionItems.isEmpty {
                md += "## Action items\n\n"
                for item in summary.actionItems {
                    let owner = item.owner.map { "**\($0)**: " } ?? ""
                    md += "- [ ] \(owner)\(item.text)\n"
                }
                md += "\n"
            }
        }

        if let enhancedNotes, !enhancedNotes.isEmpty {
            md += "## Notas\n\n\(enhancedNotes)\n\n"
        } else if let userNotes, !userNotes.isEmpty {
            md += "## Notas\n\n\(userNotes)\n\n"
        }

        if !segments.isEmpty {
            md += "## Transcrição\n\n"
            for segment in segments {
                let t = String(format: "%02d:%02d", segment.startMs / 60000, (segment.startMs / 1000) % 60)
                let who: String
                switch segment.channel {
                case .me: who = "Você"
                case .them:
                    let name = segment.speakerID.flatMap { names[$0] } ?? "Falante"
                    who = "[[\(name)]]"
                }
                md += "**[\(t)] \(who):** \(segment.text)\n\n"
            }
        }

        let vault = OuviSettings.vaultURL
        let fileURL = vault.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try md.write(to: fileURL, atomically: true, encoding: .utf8)

        try database.pool.write { db in
            guard var stored = try Session.fetchOne(db, key: sessionID) else { return }
            stored.notePath = relativePath
            try stored.update(db)
        }
        return relativePath
    }

    /// One page per person: every meeting they appeared in.
    public func writePersonPages() throws {
        let speakers = try database.pool.read { try Speaker.fetchAll($0) }
        let sessions = try database.recentSessions(limit: 10_000)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for speaker in speakers where !speaker.name.hasPrefix("Falante ") {
            let speakerSessions = try database.pool.read { db in
                try TranscriptSegment
                    .filter(Column("speaker_id") == speaker.id)
                    .fetchAll(db)
            }
            let sessionIDs = Set(speakerSessions.map(\.sessionID))
            guard !sessionIDs.isEmpty else { continue }

            var md = "---\napp: ouvi\ntype: person\n---\n\n# \(speaker.name)\n\n"
            if let company = speaker.company { md += "Empresa: [[\(company)]]\n\n" }
            md += "## Reuniões\n\n"
            for session in sessions where sessionIDs.contains(session.id) {
                let date = dateFormatter.string(from: session.startedAt)
                if let notePath = session.notePath {
                    let base = (notePath as NSString).lastPathComponent.replacingOccurrences(of: ".md", with: "")
                    md += "- \(date) — [[\(base)]]\n"
                } else {
                    md += "- \(date) — \(session.title)\n"
                }
            }
            let dir = OuviSettings.vaultURL.appendingPathComponent("Pessoas", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let fileURL = dir.appendingPathComponent("\(Self.slugify(speaker.name, allowSpaces: true)).md")
            try md.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    public static func slugify(_ text: String, allowSpaces: Bool = false) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "pt_BR"))
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: allowSpaces ? " -" : "-"))
        var slug = ""
        for scalar in folded.lowercased().unicodeScalars {
            if allowed.contains(scalar) {
                slug.append(Character(scalar))
            } else if scalar == " " || scalar == "_" {
                slug.append(allowSpaces ? " " : "-")
            }
        }
        while slug.contains("--") { slug = slug.replacingOccurrences(of: "--", with: "-") }
        let trimmed = slug.trimmingCharacters(in: CharacterSet(charactersIn: "- "))
        return String(trimmed.prefix(80))
    }

    static func yamlEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "\"", with: "\\\"")
    }
}
