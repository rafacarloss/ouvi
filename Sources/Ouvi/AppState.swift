import AppKit
import Combine
import SwiftUI
import OuviKit
import GRDB
import OSLog

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let log = Logger(subsystem: "com.rafacarloss.ouvi", category: "App")
    let database: OuviDatabase
    let dictation: DictationController
    let meetingDetector = MeetingDetector()
    let calendar = CalendarService()

    enum Nav: Hashable {
        case today
        case all
        case chat
        case person(String)
    }

    @Published var nav: Nav = .all
    @Published var sessions: [Session] = []
    @Published var people: [(speaker: Speaker, meetings: Int)] = []
    @Published var stats: OuviDatabase.VaultStats?
    @Published var selectedSessionID: String?
    let audioPlayer = AudioPlayerController()
    @Published var recording: RecordingSession?
    @Published var recordingElapsed: TimeInterval = 0
    @Published var micLevel: Float = 0
    @Published var systemLevel: Float = 0
    @Published var processingStage: MeetingProcessor.Progress.Stage?
    @Published var lastError: String?
    @Published var meetingPrompt: MeetingDetector.MicUser?
    @Published var liveMe: (confirmed: String, volatile: String) = ("", "")
    @Published var liveThem: (confirmed: String, volatile: String) = ("", "")
    @Published var importing = false

    private var levelTimer: Timer?
    private var pendingStreams: RecordingSession.Streams?
    private var liveTranscriber: LiveTranscriber?

    private init() {
        do {
            try OuviPaths.ensureDirectoriesExist()
            database = try OuviDatabase.openDefault()
        } catch {
            fatalError("Ouvi cannot open its database: \(error)")
        }
        dictation = DictationController(database: try? OuviDatabase.openDefault())
        refreshSessions()

        meetingDetector.onMeetingMicStarted = { [weak self] user in
            guard let self, self.recording == nil else { return }
            self.meetingPrompt = user
            self.notifyMeetingDetected(user)
        }
        meetingDetector.start()
        dictation.start()

        // Prewarm ASR so the first recording doesn't pay the model-load cost.
        Task.detached(priority: .background) {
            try? await TranscriptionService.shared.warmUp()
        }
        Task { await calendar.requestAccessAndStart() }
    }

    func refreshSessions() {
        sessions = (try? database.recentSessions(limit: 300)) ?? []
        people = (try? database.peopleWithCounts()) ?? []
        stats = try? database.vaultStats()
    }

    /// Resolves a citation chip: seeks in the current session, or navigates to
    /// the referenced meeting (cross-meeting short-id markers) and seeks there.
    func openCitation(sessionRef: String?, ms: Int) {
        let target: Session?
        if let ref = sessionRef, !ref.isEmpty {
            target = sessions.first { $0.id.lowercased().hasPrefix(ref.lowercased()) }
        } else if let id = selectedSessionID {
            target = sessions.first { $0.id == id }
        } else {
            target = nil
        }
        guard let target else { return }
        selectedSessionID = target.id
        if case .chat = nav {} else { nav = .all }
        audioPlayer.play(session: target, atMs: ms)
    }

    // MARK: Recording

    var isRecording: Bool { recording != nil }

    func startRecording(title: String? = nil) {
        guard recording == nil else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM HH:mm"
        dateFormatter.locale = Locale(identifier: "pt_BR")
        let calendarMeeting = calendar.currentMeeting
        let session = RecordingSession(
            database: database,
            title: title ?? calendarMeeting?.title ?? "Reunião \(dateFormatter.string(from: Date()))",
            calendarEventID: calendarMeeting?.id)

        // Live draft transcription, fed from the capture callbacks.
        liveMe = ("", "")
        liveThem = ("", "")
        let live = LiveTranscriber()
        live.onUpdate = { [weak self] update in
            guard let self else { return }
            switch update.channel {
            case .me: self.liveMe = (update.confirmed, update.volatile)
            case .them: self.liveThem = (update.confirmed, update.volatile)
            }
        }
        session.onMicBuffer = { [weak live] buffer in live?.feedMic(buffer) }
        session.onSystemBuffer = { [weak live] buffer in live?.feedSystem(buffer) }

        do {
            try session.start()
            liveTranscriber = live
            Task {
                do { try await live.start() } catch {
                    self.log.error("live transcription unavailable: \(error.localizedDescription)")
                }
            }
            recording = session
            meetingPrompt = nil
            recordingElapsed = 0
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, let rec = self.recording else { return }
                    self.micLevel = rec.micLevel
                    self.systemLevel = rec.systemLevel
                    if let started = rec.startedAt {
                        self.recordingElapsed = Date().timeIntervalSince(started)
                    }
                }
            }
            refreshSessions()
            selectedSessionID = session.session.id
        } catch {
            lastError = "Não consegui iniciar a gravação: \(error.localizedDescription)"
            log.error("start recording failed: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        guard let session = recording else { return }
        levelTimer?.invalidate()
        levelTimer = nil
        recording = nil
        if let live = liveTranscriber {
            liveTranscriber = nil
            Task { await live.stop() }
        }
        do {
            let streams = try session.stop()
            pendingStreams = streams
            if !session.systemSignalObserved {
                lastError = """
                O áudio do sistema veio vazio — só o seu microfone foi gravado. \
                Verifique Ajustes do Sistema → Privacidade e Segurança → Gravação \
                de Áudio do Sistema e autorize o Ouvi, depois grave de novo. \
                (Detalhes técnicos: \(session.systemDiagnostics))
                """
            }
            refreshSessions()
            processingStage = .transcribingMic
            let processor = MeetingProcessor(database: database)
            let languageHint = OuviSettings.effectiveLanguageHint
            Task {
                do {
                    try await processor.process(
                        session: session, streams: streams, languageHint: languageHint
                    ) { progress in
                        Task { @MainActor in self.processingStage = progress.stage }
                    }
                    // Best-effort auto-title, then project into the vault.
                    await MeetingIntelligence(database: self.database)
                        .autoTitleIfNeeded(sessionID: session.session.id)
                    let writer = VaultWriter(database: self.database)
                    _ = try? writer.writeNote(sessionID: session.session.id, userNotes: self.notesDrafts[session.session.id], enhancedNotes: nil)
                    try? writer.writePersonPages()
                } catch {
                    await MainActor.run {
                        self.lastError = "Falha ao processar a gravação: \(error.localizedDescription)"
                    }
                }
                await MainActor.run {
                    self.processingStage = nil
                    self.refreshSessions()
                }
            }
        } catch {
            lastError = "Falha ao encerrar a gravação: \(error.localizedDescription)"
        }
    }

    // MARK: Import

    func importAudioFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        importing = true
        let languageHint = OuviSettings.effectiveLanguageHint
        Task {
            let service = ImportService(database: database)
            for url in urls {
                do {
                    let id = try await service.importFile(at: url, languageHint: languageHint)
                    await MainActor.run { self.selectedSessionID = id }
                } catch {
                    await MainActor.run {
                        self.lastError = "Falha ao importar \(url.lastPathComponent): \(error.localizedDescription)"
                    }
                }
                await MainActor.run { self.refreshSessions() }
            }
            await MainActor.run { self.importing = false }
        }
    }

    // MARK: Notes (in-meeting notepad drafts, keyed by session; persisted to DB)

    @Published var notesDrafts: [String: String] = [:]

    func saveNotes(sessionID: String, userNotes: String?, enhancedNotes: String?) {
        try? database.pool.write { db in
            guard var session = try Session.fetchOne(db, key: sessionID) else { return }
            if let userNotes { session.userNotes = userNotes }
            if let enhancedNotes { session.enhancedNotes = enhancedNotes }
            try session.update(db)
        }
    }

    // MARK: Session management

    func deleteSession(_ session: Session) {
        try? database.pool.write { db in
            var s = session
            s.deletedAt = Date()
            try s.update(db)
        }
        if selectedSessionID == session.id { selectedSessionID = nil }
        refreshSessions()
    }

    func renameSession(_ session: Session, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        try? database.pool.write { db in
            var s = session
            s.title = trimmed
            try s.update(db)
        }
        refreshSessions()
        let writer = VaultWriter(database: database)
        _ = try? writer.writeNote(sessionID: session.id, userNotes: session.userNotes, enhancedNotes: session.enhancedNotes)
    }

    // MARK: Meeting-detected notification

    private func notifyMeetingDetected(_ user: MeetingDetector.MicUser) {
        let notification = NSUserNotification()
        notification.title = "\(user.displayName) está usando o microfone"
        notification.informativeText = "Quer gravar essa reunião com o Ouvi?"
        notification.hasActionButton = true
        notification.actionButtonTitle = "Gravar"
        NSUserNotificationCenter.default.deliver(notification)
    }
}
