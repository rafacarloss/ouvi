import SwiftUI
import OuviKit

struct MainWindow: View {
    @EnvironmentObject var state: AppState
    @State private var searchText = ""
    @State private var searchResults: [TranscriptSegment] = []

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 290)
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
            ToolbarItem(placement: .primaryAction) {
                RecordButton()
            }
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
}

struct SessionRow: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(session.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
                stateBadge
            }
            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var stateBadge: some View {
        switch session.state {
        case .recording:
            Image(systemName: "record.circle").foregroundStyle(.red)
        case .transcribing:
            ProgressView().controlSize(.mini)
        case .failed:
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
        case .ready:
            if session.usedCloud {
                Image(systemName: "cloud").font(.caption2).foregroundStyle(.secondary)
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
                Label(elapsed, systemImage: "stop.circle.fill")
                    .foregroundStyle(.red)
            }
            .help("Parar e transcrever")
        } else if let stage = state.processingStage {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(stageLabel(stage)).font(.caption)
            }
        } else {
            Button {
                state.startRecording()
            } label: {
                Label("Gravar", systemImage: "record.circle")
            }
            .help("Gravar reunião (mic + áudio do sistema, tudo local)")
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
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Suas reuniões, no seu Mac.")
                .font(.title3.weight(.semibold))
            Text("Clique em Gravar durante uma call — sem bot, sem nuvem.\nSegure Fn para ditar em qualquer app.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Gravar agora") { state.startRecording() }
                .keyboardShortcut("r", modifiers: [.command])
        }
        .padding()
    }
}
