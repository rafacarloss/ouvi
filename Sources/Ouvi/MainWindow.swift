import SwiftUI
import OuviKit
import GRDB

/// The kit's MainWindow: nav sidebar (248) · session list (300) · content.
struct MainWindow: View {
    @EnvironmentObject var state: AppState
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasOnboarded")

    var body: some View {
        HStack(spacing: 0) {
            NavSidebar()
                .frame(width: DS.sidebarWidth)
            Divider().overlay(DS.borderHairline)

            switch state.nav {
            case .today, .all:
                SessionListColumn()
                    .frame(width: 300)
                Divider().overlay(DS.borderHairline)
                if let id = state.selectedSessionID {
                    SessionDetailView(sessionID: id)
                        .id(id)
                } else {
                    EmptyStateView()
                }
            case .chat:
                SearchChatView()
            case .person(let speakerID):
                PersonPageView(speakerID: speakerID)
                    .id(speakerID)
            }
        }
        .background(DS.bgWindow)
        .onOpenCitation { ref, ms in state.openCitation(sessionRef: ref, ms: ms) }
        .onReceive(state.audioPlayer.$playbackError) { error in
            if let error {
                state.lastError = error
                state.audioPlayer.playbackError = nil
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .alert("Ops", isPresented: Binding(
            get: { state.lastError != nil },
            set: { if !$0 { state.lastError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(state.lastError ?? "")
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        Task { @MainActor in state.importAudioFiles([url]) }
                    }
                }
            }
            return true
        }
    }
}

// MARK: - Nav sidebar

struct NavSidebar: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text("ouvi")
                    .font(DS.sans(17, .black))
                    .tracking(-0.5)
                    .foregroundStyle(DS.textTitle)
                Circle().fill(DS.live).frame(width: 5, height: 5).offset(y: 4)
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 10)

            SidebarItem(icon: "calendar", label: "Hoje", count: todayCount, selected: state.nav == .today) {
                state.nav = .today
            }
            SidebarItem(icon: "waveform", label: "Todas as reuniões", count: state.sessions.count, selected: state.nav == .all) {
                state.nav = .all
            }
            SidebarItem(icon: "text.bubble", label: "Conversar com o histórico", count: nil, selected: state.nav == .chat) {
                state.nav = .chat
            }

            if !state.people.isEmpty {
                Text("PESSOAS")
                    .font(DS.mono(10, .bold))
                    .tracking(1.0)
                    .foregroundStyle(DS.textFaint)
                    .padding(.horizontal, 8)
                    .padding(.top, 14)
                    .padding(.bottom, 4)
                ForEach(state.people.prefix(8), id: \.speaker.id) { entry in
                    if !entry.speaker.name.hasPrefix("Falante ") {
                        SidebarItem(
                            icon: "person",
                            label: entry.speaker.name,
                            count: entry.meetings,
                            selected: state.nav == .person(entry.speaker.id),
                            indent: true
                        ) {
                            state.nav = .person(entry.speaker.id)
                        }
                    }
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                PrivacyBadge(mode: .local, detail: "tudo neste Mac")
                if let stats = state.stats {
                    Text("~/Ouvi · \(stats.notes) notas · \(stats.people) pessoas")
                        .font(DS.monoXS)
                        .foregroundStyle(DS.textFaint)
                }
            }
            .padding(8)
        }
        .padding(8)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(DS.bgSidebar)
    }

    private var todayCount: Int {
        state.sessions.filter { Calendar.current.isDateInToday($0.startedAt) }.count
            + state.calendar.todaysMeetings.count
    }
}

struct SidebarItem: View {
    let icon: String
    let label: String
    var count: Int?
    var selected = false
    var indent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(selected ? DS.accentSoftText : DS.textMuted)
                    .frame(width: 16)
                Text(label)
                    .font(selected ? DS.bodyMedium : DS.body)
                    .foregroundStyle(selected ? DS.textTitle : DS.textBody)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let count {
                    Text("\(count)")
                        .font(DS.monoXS)
                        .foregroundStyle(DS.textFaint)
                }
            }
            .padding(.leading, indent ? 14 : 8)
            .padding(.trailing, 8)
            .padding(.vertical, 5)
            .background(selected ? DS.bgSelected : .clear, in: RoundedRectangle(cornerRadius: DS.radiusControl))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session list column

struct SessionListColumn: View {
    @EnvironmentObject var state: AppState
    @State private var searchText = ""
    @State private var searchResults: [TranscriptSegment] = []
    @State private var renaming: Session?
    @State private var deleting: Session?

    private var listedSessions: [Session] {
        state.nav == .today
            ? state.sessions.filter { Calendar.current.isDateInToday($0.startedAt) }
            : state.sessions
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.textFaint)
                TextField("Buscar em tudo", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(DS.body)
                Button {
                    importAudio()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.textMuted)
                }
                .buttonStyle(.plain)
                .disabled(state.importing)
                .help("Importar arquivo de áudio")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(DS.bgInset, in: RoundedRectangle(cornerRadius: DS.radiusControl))
            .padding(8)
            Divider().overlay(DS.borderHairline)

            if state.nav == .today {
                TodayMeetingsHeader()
            }

            ScrollView {
                LazyVStack(spacing: 1) {
                    if !searchText.isEmpty {
                        ForEach(searchResults, id: \.id) { hit in
                            SearchHitRow(hit: hit)
                        }
                        if searchResults.isEmpty {
                            Text("Nada encontrado para \"\(searchText)\".")
                                .font(DS.caption)
                                .foregroundStyle(DS.textFaint)
                                .padding(12)
                        }
                    } else {
                        ForEach(listedSessions) { session in
                            SessionRow(session: session, selected: state.selectedSessionID == session.id)
                                .onTapGesture { state.selectedSessionID = session.id }
                                .contextMenu {
                                    Button("Renomear…") { renaming = session }
                                    Button("Exportar .md") { quickExport(session) }
                                    Divider()
                                    Button("Apagar reunião", role: .destructive) { deleting = session }
                                }
                        }
                    }
                }
                .padding(6)
            }
        }
        .background(DS.bgWindow)
        .onChange(of: searchText) { _, query in
            searchResults = query.count >= 2
                ? ((try? state.database.searchSegments(matching: query, limit: 30)) ?? [])
                : []
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                RecordButton()
            }
        }
        .sheet(item: $renaming) { session in
            RenameSessionSheet(session: session) { title in
                state.renameSession(session, to: title)
            }
        }
        .confirmationDialog(
            "Apagar \"\(deleting?.title ?? "")\"?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
        ) {
            Button("Apagar reunião", role: .destructive) {
                if let session = deleting { state.deleteSession(session) }
                deleting = nil
            }
            Button("Cancelar", role: .cancel) { deleting = nil }
        } message: {
            Text("A nota no vault e o áudio ficam no disco; a reunião some do app.")
        }
    }

    private func quickExport(_ session: Session) {
        guard let content = try? ExportService.export(
            sessionID: session.id, format: .markdown, database: state.database)
        else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(VaultWriter.slugify(session.title)).md"
        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func importAudio() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.audio, .movie, .mpeg4Movie, .wav, .mp3]
        panel.prompt = "Importar e transcrever"
        if panel.runModal() == .OK {
            state.importAudioFiles(panel.urls)
        }
    }
}

struct SearchHitRow: View {
    @EnvironmentObject var state: AppState
    let hit: TranscriptSegment

    var body: some View {
        Button {
            state.selectedSessionID = hit.sessionID
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(state.sessions.first { $0.id == hit.sessionID }?.title ?? "Reunião")
                        .font(DS.sans(11, .medium))
                        .foregroundStyle(DS.textMuted)
                        .lineLimit(1)
                    TimeCode(ms: hit.startMs)
                }
                Text(hit.text)
                    .font(DS.caption)
                    .foregroundStyle(DS.textBody)
                    .lineLimit(2)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SessionRow: View {
    @EnvironmentObject var state: AppState
    let session: Session
    var selected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(session.title)
                    .font(DS.bodyMedium)
                    .foregroundStyle(DS.textBody)
                    .lineLimit(1)
                Spacer()
                stateBadge
            }
            Text(metaLine)
                .font(DS.monoXS)
                .foregroundStyle(DS.textFaint)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(selected ? DS.bgSelected : .clear, in: RoundedRectangle(cornerRadius: DS.radiusControl))
        .contentShape(Rectangle())
    }

    private var metaLine: String {
        var parts = [Self.relativeDate(session.startedAt)]
        if let ended = session.endedAt {
            parts.append("\(max(1, Int(ended.timeIntervalSince(session.startedAt) / 60))) min")
        }
        if let count = try? state.database.speakerCount(sessionID: session.id), count > 1 {
            parts.append("\(count) falantes")
        }
        return parts.joined(separator: " · ")
    }

    static func relativeDate(_ date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(date) { return "hoje \(time)" }
        if Calendar.current.isDateInYesterday(date) { return "ontem \(time)" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: date)) \(time)"
    }

    @ViewBuilder
    private var stateBadge: some View {
        switch session.state {
        case .recording:
            Circle().fill(DS.live).frame(width: 7, height: 7)
        case .transcribing:
            ProgressView().controlSize(.mini)
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 10))
                .foregroundStyle(DS.caution)
        case .ready:
            if session.usedCloud {
                MicroBadge(text: "NUVEM", color: DS.caution, background: DS.cautionSoft)
                    .help("Nuvem usada nesta reunião — apenas o texto do transcript foi enviado.")
            }
        }
    }
}

struct RenameSessionSheet: View {
    let session: Session
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Renomear reunião")
                .font(DS.title3)
            TextField("Título", text: $title)
                .onSubmit { save() }
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Salvar") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear { title = session.title }
    }

    private func save() {
        onSave(title)
        dismiss()
    }
}

/// Today's calendar meetings, with one-click record for the one happening now.
struct TodayMeetingsHeader: View {
    @EnvironmentObject var state: AppState
    @ObservedObject private var calendar: CalendarService

    init() {
        _calendar = ObservedObject(wrappedValue: AppState.shared.calendar)
    }

    var body: some View {
        if calendar.accessGranted && !calendar.todaysMeetings.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("AGENDA")
                    .font(DS.mono(10, .bold))
                    .tracking(1.0)
                    .foregroundStyle(DS.textFaint)
                ForEach(calendar.todaysMeetings) { meeting in
                    HStack(spacing: 6) {
                        Text(meeting.start.formatted(date: .omitted, time: .shortened))
                            .font(DS.monoXS)
                            .foregroundStyle(DS.textFaint)
                        Text(meeting.title)
                            .font(DS.caption)
                            .foregroundStyle(DS.textBody)
                            .lineLimit(1)
                        Spacer()
                        if meeting.isNow && !state.isRecording {
                            Button("Gravar") {
                                state.startRecording(title: meeting.title)
                            }
                            .font(DS.caption)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider().overlay(DS.borderHairline)
        }
    }
}

struct RecordButton: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        if state.isRecording {
            Button {
                state.stopRecording()
            } label: {
                HStack(spacing: 7) {
                    Circle().fill(DS.textOnAccent).frame(width: 7, height: 7)
                    Text("AO VIVO · \(elapsed)")
                        .font(DS.mono(11, .bold))
                        .tracking(0.5)
                }
                .foregroundStyle(DS.textOnAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(DS.accent, in: Capsule())
                .shadow(color: DS.liveGlow, radius: 8)
            }
            .buttonStyle(.plain)
            .help("Parar e transcrever")
        } else if let stage = state.processingStage {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(stageLabel(stage)).font(DS.caption).foregroundStyle(DS.textMuted)
            }
        } else {
            Button {
                state.startRecording()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                    Text("Gravar")
                        .font(DS.bodyMedium)
                }
                .foregroundStyle(DS.textOnAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(DS.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .help("Gravar reunião — mic + áudio do sistema, tudo neste Mac")
        }
    }

    private var elapsed: String {
        let s = Int(state.recordingElapsed)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func stageLabel(_ stage: MeetingProcessor.Progress.Stage) -> String {
        switch stage {
        case .transcribingMic, .transcribingSystem: return "Transcrevendo…"
        case .diarizing: return "Identificando falantes…"
        case .saving: return "Salvando…"
        case .archiving: return "Arquivando áudio…"
        case .done: return "Pronto"
        }
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 5) {
                Text("ouvi")
                    .font(DS.sans(34, .black))
                    .tracking(-1.0)
                    .foregroundStyle(DS.textTitle)
                Circle().fill(DS.accent).frame(width: 8, height: 8)
                    .offset(y: 8)
            }
            Text("Nada ainda. Grave uma reunião ou solte um arquivo de áudio aqui.")
                .font(DS.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(DS.textMuted)
            PrimaryButton(title: "Gravar agora", icon: "circle.fill") { state.startRecording() }
            Text("Segure fn para ditar em qualquer app")
                .font(DS.monoXS)
                .foregroundStyle(DS.textFaint)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.bgSurface)
    }
}
