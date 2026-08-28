import Foundation
import GRDB

/// Free, complete exports — the user's data leaves in any format, always.
public enum ExportService {
    public enum Format: String, CaseIterable, Sendable {
        case markdown = "md"
        case srt
        case vtt
        case json
    }

    public static func export(sessionID: String, format: Format, database: OuviDatabase) throws -> String {
        guard let session = try database.session(id: sessionID) else {
            throw NSError(domain: "Ouvi", code: 404, userInfo: [NSLocalizedDescriptionKey: "session not found"])
        }
        let segments = try database.segments(sessionID: sessionID)
        let speakers = try database.pool.read { try Speaker.fetchAll($0) }
        let names = Dictionary(uniqueKeysWithValues: speakers.map { ($0.id, $0.name) })

        func speaker(_ segment: TranscriptSegment) -> String {
            segment.channel == .me ? "Eu" : (segment.speakerID.flatMap { names[$0] } ?? "Participante")
        }

        switch format {
        case .markdown:
            var md = "# \(session.title)\n\n"
            for s in segments {
                let t = String(format: "%02d:%02d", s.startMs / 60000, (s.startMs / 1000) % 60)
                md += "**[\(t)] \(speaker(s)):** \(s.text)\n\n"
            }
            return md

        case .srt:
            return segments.enumerated().map { index, s in
                "\(index + 1)\n\(srtTime(s.startMs)) --> \(srtTime(s.endMs))\n\(speaker(s)): \(s.text)\n"
            }.joined(separator: "\n")

        case .vtt:
            let body = segments.map { s in
                "\(vttTime(s.startMs)) --> \(vttTime(s.endMs))\n<v \(speaker(s))>\(s.text)"
            }.joined(separator: "\n\n")
            return "WEBVTT\n\n" + body + "\n"

        case .json:
            let payload: [String: Any] = [
                "id": session.id,
                "title": session.title,
                "started_at": ISO8601DateFormatter().string(from: session.startedAt),
                "language": session.language ?? "auto",
                "segments": segments.map { s in
                    [
                        "start_ms": s.startMs,
                        "end_ms": s.endMs,
                        "channel": s.channel.rawValue,
                        "speaker": speaker(s),
                        "text": s.text,
                    ] as [String: Any]
                },
            ]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            return String(data: data, encoding: .utf8) ?? "{}"
        }
    }

    private static func srtTime(_ ms: Int) -> String {
        String(format: "%02d:%02d:%02d,%03d", ms / 3_600_000, (ms / 60000) % 60, (ms / 1000) % 60, ms % 1000)
    }

    private static func vttTime(_ ms: Int) -> String {
        String(format: "%02d:%02d:%02d.%03d", ms / 3_600_000, (ms / 60000) % 60, (ms / 1000) % 60, ms % 1000)
    }
}
