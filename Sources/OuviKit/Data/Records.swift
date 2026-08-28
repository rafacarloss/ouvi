import Foundation
import GRDB

/// A recorded session: a meeting, an imported file, or a dictation capture.
public struct Session: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "session"

    public enum Kind: String, Codable {
        case meeting
        case importedFile = "import"
        case dictation
    }

    public enum State: String, Codable {
        case recording
        case transcribing
        case ready
        case failed
    }

    public var id: String
    public var kind: Kind
    public var state: State
    public var title: String
    public var startedAt: Date
    public var endedAt: Date?
    /// Calendar event identifier (EventKit) when the session was linked to an event.
    public var calendarEventID: String?
    public var micAudioPath: String?
    public var systemAudioPath: String?
    /// Relative path of the Markdown note inside the vault.
    public var notePath: String?
    public var language: String?
    public var summaryJSON: String?
    public var userNotes: String?
    public var enhancedNotes: String?
    /// True when a cloud LLM was used for any processing of this session.
    public var usedCloud: Bool
    public var createdAt: Date
    public var deletedAt: Date?

    public init(
        id: String = UUID().uuidString,
        kind: Kind,
        state: State = .recording,
        title: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        calendarEventID: String? = nil,
        micAudioPath: String? = nil,
        systemAudioPath: String? = nil,
        notePath: String? = nil,
        language: String? = nil,
        summaryJSON: String? = nil,
        userNotes: String? = nil,
        enhancedNotes: String? = nil,
        usedCloud: Bool = false,
        createdAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.state = state
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.calendarEventID = calendarEventID
        self.micAudioPath = micAudioPath
        self.systemAudioPath = systemAudioPath
        self.notePath = notePath
        self.language = language
        self.summaryJSON = summaryJSON
        self.userNotes = userNotes
        self.enhancedNotes = enhancedNotes
        self.usedCloud = usedCloud
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }
}

/// One utterance in the final transcript.
public struct TranscriptSegment: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "segment"

    public enum Channel: String, Codable, Sendable {
        /// The user's microphone.
        case me
        /// Remote participants (system audio).
        case them
    }

    public var id: String
    public var sessionID: String
    public var startMs: Int
    public var endMs: Int
    public var channel: Channel
    public var speakerID: String?
    public var text: String
    /// JSON-encoded per-word timings: [{"w": "hello", "s": 120, "e": 300}].
    public var wordsJSON: String?
    /// True while this segment only exists from the live streaming pass.
    public var isDraft: Bool

    public init(
        id: String = UUID().uuidString,
        sessionID: String,
        startMs: Int,
        endMs: Int,
        channel: Channel,
        speakerID: String? = nil,
        text: String,
        wordsJSON: String? = nil,
        isDraft: Bool = false
    ) {
        self.id = id
        self.sessionID = sessionID
        self.startMs = startMs
        self.endMs = endMs
        self.channel = channel
        self.speakerID = speakerID
        self.text = text
        self.wordsJSON = wordsJSON
        self.isDraft = isDraft
    }

    enum CodingKeys: String, CodingKey {
        case id, sessionID = "session_id", startMs = "start_ms", endMs = "end_ms",
             channel, speakerID = "speaker_id", text, wordsJSON = "words_json", isDraft = "is_draft"
    }
}

/// A known person. Voice centroids stay local-only forever.
public struct Speaker: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "speaker"

    public var id: String
    public var name: String
    public var company: String?
    /// Binary little-endian float32 array; nil until enrolled.
    public var voiceCentroid: Data?
    public var enrollmentCount: Int
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        company: String? = nil,
        voiceCentroid: Data? = nil,
        enrollmentCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.company = company
        self.voiceCentroid = voiceCentroid
        self.enrollmentCount = enrollmentCount
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, company, voiceCentroid = "voice_centroid",
             enrollmentCount = "enrollment_count", createdAt = "created_at"
    }
}

/// RAG chunk over transcripts and notes; embeddings live in the vec0 virtual table keyed by rowid.
public struct Chunk: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "chunk"

    public var id: Int64?
    public var sessionID: String
    public var startMs: Int?
    public var endMs: Int?
    public var text: String

    public var identifier: Int64 { id ?? -1 }

    public init(id: Int64? = nil, sessionID: String, startMs: Int?, endMs: Int?, text: String) {
        self.id = id
        self.sessionID = sessionID
        self.startMs = startMs
        self.endMs = endMs
        self.text = text
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    enum CodingKeys: String, CodingKey {
        case id, sessionID = "session_id", startMs = "start_ms", endMs = "end_ms", text
    }
}

/// User dictionary entry: jargon, names, replacements for dictation and ASR prompts.
public struct DictionaryEntry: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "dictionary_entry"

    public var id: String
    public var phrase: String
    /// Optional replacement; when nil the phrase is a protected proper noun / hotword.
    public var replacement: String?
    public var createdAt: Date

    public init(id: String = UUID().uuidString, phrase: String, replacement: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.phrase = phrase
        self.replacement = replacement
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, phrase, replacement, createdAt = "created_at"
    }
}
