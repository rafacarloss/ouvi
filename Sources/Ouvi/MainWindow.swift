import SwiftUI
import OuviKit

struct MainWindow: View {
    @EnvironmentObject var state: AppState
    @State private var searchText = ""
    @State private var searchResults: [TranscriptSegment] = []
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasOnboarded")

    var body: some View {
        NavigationSplitView {
            sidebar
                .background(DS.bgSidebar)
                .navigationSplitViewColumnWidth(min: DS.sidebarWidth, ideal: DS.sidebarWidth)
        } detail: {
            if let id = state.selectedSessionID {
                SessionDetailView(sessionID: id)
                    .id(id)
            } else {
                EmptyStateView()
            }
        }
        .searchable(text: $searchText, prompt: "Buscar nas reuniões")
        .onChange(of: searchText) { _, query in
            searchResults = query.count >= 2
                ? ((try? state.database.searchSegments(matching: query, limit: 30)) ?? [])
                : []
        }
        .toolbar {
            ToolbarItem {
                Button {
                    importAudio()
                } label: {
                    Label("Importar áudio", systemImage: "square.and.arrow.down")
                }
                .disabled(state.importing)
                .help("Transcrever um arquivo de áudio ou vídeo já gravado")
            }
            ToolbarItem(placement: .primaryAction) {
                RecordButton()
            }
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
    }

    @ViewBuilder
    private var sidebar: some View {
        if searchText.isEmpty {
            TodayMeetingsHeader()
        }
        if !searchText.isEmpty && !searchResults.isEmpty {
            List(searchResults, id: \.id, selection: $state.selectedSessionID) { hit in
                VStack(alignment: .leading, spacing: 2) {
                    Text(sessionTitle(hit.sessionID))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(hit.text)
                        .lineLimit(2)
                }
                .tag(hit.sessionID)
            }
        } else {
            List(state.sessions, selection: $state.selectedSessionID) { session in
                SessionRow(session: session)
                    .tag(session.id)
            }
        }
    }

    private func sessionTitle(_ id: String) -> String {
        state.sessions.first(where: { $0.id == id })?.title ?? "Reunião"
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

/// Today's calendar meetings, with one-click record for the one happening now.
struct TodayMeetingsHeader: View {
    @EnvironmentObject var state: AppState
    @ObservedObject private var calendar: CalendarService

    init() {
        // ObservedObject needs the instance at init; environment isn't set yet.
        _calendar = ObservedObject(wrappedValue: AppState.shared.calendar)
    }

    var body: some View {
        if calendar.accessGranted && !calendar.todaysMeetings.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("HOJE")
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
                            .font(.caption)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

struct SessionRow: View {
    let session: Session

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
            HStack(spacing: 4) {
                Text(Self.relativeDate(session.startedAt))
                    .font(DS.monoXS)
                    .foregroundStyle(DS.textFaint)
                if let ended = session.endedAt {
                    Text("·").foregroundStyle(DS.textFaint)
                    Text("\(max(1, Int(ended.timeIntervalSince(session.startedAt) / 60))) min")
                        .font(DS.monoXS)
                        .foregroundStyle(DS.textFaint)
                }
            }
        }
        .padding(.vertical, 5)
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
            } else {
                MicroBadge(text: "LOCAL")
                    .help("Tudo neste Mac")
            }
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
            Button("Gravar agora") { state.startRecording() }
                .keyboardShortcut("r", modifiers: [.command])
            Text("Segure fn para ditar em qualquer app")
                .font(DS.monoXS)
                .foregroundStyle(DS.textFaint)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.bgWindow)
    }
}
