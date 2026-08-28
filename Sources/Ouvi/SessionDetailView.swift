import AVFoundation
import SwiftUI
import OuviKit
import GRDB

struct SessionDetailView: View {
    @EnvironmentObject var state: AppState
    let sessionID: String

    @State private var session: Session?
    @State private var segments: [TranscriptSegment] = []
    @State private var speakerNames: [String: String] = [:]
    @State private var notes: String = ""
    @State private var enhanced: String?
    @State private var summary: MeetingSummary?
    @State private var busy: String?
    @State private var chatQuestion = ""
    @State private var chatAnswer: String?
    @State private var player: AVAudioPlayer?
    @State private var renamingSpeaker: Speaker?

    var body: some View {
        HSplitView {
            notesColumn
                .frame(minWidth: 320)
            transcriptColumn
                .frame(minWidth: 300)
        }
        .navigationTitle(session?.title ?? "Reunião")
        .task(id: sessionID) { load() }
        .onReceive(state.$processingStage) { stage in
            if stage == nil { load() }
        }
    }

    // MARK: Notes + summary column

    private var notesColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let summary {
                        SummaryView(summary: summary)
                    }
                    Text("Suas notas")
                        .font(.headline)
                    TextEditor(text: $notes)
                        .font(.body)
                        .frame(minHeight: 160)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                        .onChange(of: notes) { _, new in
                            state.notesDrafts[sessionID] = new
                        }
                    if let enhanced {
                        Text("Notas aprimoradas")
                            .font(.headline)
                        Text(LocalizedStringKey(enhanced))
                            .textSelection(.enabled)
                    }
                    if let chatAnswer {
                        Text("Resposta")
                            .font(.headline)
                        Text(LocalizedStringKey(chatAnswer))
                            .textSelection(.enabled)
                    }
                }
                .padding()
            }
            Divider()
            actionBar
        }
    }

    private var actionBar: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    run("Aprimorando notas…") {
                        let intelligence = MeetingIntelligence(database: state.database)
                        enhanced = try await intelligence.enhanceNotes(sessionID: sessionID, userNotes: notes)
                        persistNote()
                    }
                } label: {
                    Label("Aprimorar notas", systemImage: "wand.and.stars")
                }
                .disabled(busy != nil || segments.isEmpty || notes.isEmpty)

                Button {
                    run("Resumindo…") {
                        let intelligence = MeetingIntelligence(database: state.database)
                        summary = try await intelligence.summarize(sessionID: sessionID, userNotes: notes)
                        persistNote()
                        load()
                    }
                } label: {
                    Label("Resumir", systemImage: "text.badge.star")
                }
                .disabled(busy != nil || segments.isEmpty)

                Spacer()
                if let busy {
                    ProgressView().controlSize(.small)
                    Text(busy).font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                TextField("Pergunte sobre essa reunião…", text: $chatQuestion)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { ask() }
                Button("Perguntar") { ask() }
                    .disabled(busy != nil || chatQuestion.isEmpty || segments.isEmpty)
            }
        }
        .padding(10)
    }

    // MARK: Transcript column

    private var transcriptColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Transcrição")
                    .font(.headline)
                Spacer()
                if session?.state == .ready, session?.micAudioPath != nil {
                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: player?.isPlaying == true ? "pause.circle" : "play.circle")
                    }
                    .buttonStyle(.plain)
                    .help("Ouvir o áudio da reunião")
                }
            }
            .padding([.horizontal, .top])
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(segments) { segment in
                        SegmentView(
                            segment: segment,
                            speakerName: name(for: segment),
                            onRename: { beginRename(segment) },
                            onSeek: { seek(toMs: segment.startMs) })
                    }
                    if segments.isEmpty {
                        Text(session?.state == .transcribing
                             ? "Transcrevendo…"
                             : "Sem transcrição ainda.")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }
                .padding()
            }
        }
        .sheet(item: $renamingSpeaker) { speaker in
            RenameSpeakerSheet(speaker: speaker) { newName, company in
                rename(speaker: speaker, to: newName, company: company)
            }
        }
    }

    // MARK: Data

    private func load() {
        session = try? state.database.session(id: sessionID)
        segments = (try? state.database.segments(sessionID: sessionID)) ?? []
        let speakers = (try? state.database.pool.read { try Speaker.fetchAll($0) }) ?? []
        speakerNames = Dictionary(uniqueKeysWithValues: speakers.map { ($0.id, $0.name) })
        notes = state.notesDrafts[sessionID] ?? notes
        if summary == nil, let json = session?.summaryJSON?.data(using: .utf8) {
            summary = try? JSONDecoder().decode(MeetingSummary.self, from: json)
        }
    }

    private func name(for segment: TranscriptSegment) -> String {
        switch segment.channel {
        case .me: return "Eu"
        case .them: return segment.speakerID.flatMap { speakerNames[$0] } ?? "Participante"
        }
    }

    private func run(_ label: String, _ work: @escaping () async throws -> Void) {
        busy = label
        Task {
            do { try await work() } catch {
                state.lastError = error.localizedDescription
            }
            busy = nil
        }
    }

    private func ask() {
        let question = chatQuestion
        run("Pensando…") {
            let intelligence = MeetingIntelligence(database: state.database)
            chatAnswer = try await intelligence.chat(sessionID: sessionID, question: question)
        }
    }

    private func persistNote() {
        let writer = VaultWriter(database: state.database)
        _ = try? writer.writeNote(sessionID: sessionID, userNotes: notes, enhancedNotes: enhanced)
        try? writer.writePersonPages()
    }

    // MARK: Speakers

    private func beginRename(_ segment: TranscriptSegment) {
        guard let speakerID = segment.speakerID else { return }
        renamingSpeaker = try? state.database.pool.read { try Speaker.fetchOne($0, key: speakerID) }
    }

    private func rename(speaker: Speaker, to newName: String, company: String) {
        try? state.database.pool.write { db in
            var s = speaker
            s.name = newName
            s.company = company.isEmpty ? nil : company
            try s.update(db)
        }
        load()
        persistNote()
    }

    // MARK: Audio

    private func togglePlayback() {
        if let player, player.isPlaying {
            player.pause()
            return
        }
        guard let path = session?.micAudioPath else { return }
        // Play the system channel when available — that's usually the meeting.
        let url = URL(fileURLWithPath: session?.systemAudioPath ?? path)
        if player == nil {
            player = try? AVAudioPlayer(contentsOf: url)
        }
        player?.play()
    }

    private func seek(toMs ms: Int) {
        guard let path = session?.systemAudioPath ?? session?.micAudioPath else { return }
        if player == nil {
            player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
        }
        player?.currentTime = Double(ms) / 1000
        player?.play()
    }
}

struct SegmentView: View {
    let segment: TranscriptSegment
    let speakerName: String
    let onRename: () -> Void
    let onSeek: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Button(action: onSeek) {
                    Text(timestamp)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                Text(speakerName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(segment.channel == .me ? Color.accentColor : .secondary)
                    .onTapGesture(count: 2) { onRename() }
                    .help(segment.channel == .them ? "Duplo clique para nomear" : "")
            }
            Text(segment.text)
                .textSelection(.enabled)
        }
    }

    private var timestamp: String {
        String(format: "%02d:%02d", segment.startMs / 60000, (segment.startMs / 1000) % 60)
    }
}

struct SummaryView: View {
    let summary: MeetingSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary.overview)
                .foregroundStyle(.secondary)
            ForEach(summary.topics.indices, id: \.self) { i in
                let topic = summary.topics[i]
                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.heading).font(.subheadline.weight(.semibold))
                    ForEach(topic.bullets.indices, id: \.self) { j in
                        Text("• \(topic.bullets[j])")
                    }
                }
            }
            if !summary.actionItems.isEmpty {
                Text("Action items").font(.subheadline.weight(.semibold))
                ForEach(summary.actionItems.indices, id: \.self) { i in
                    let item = summary.actionItems[i]
                    Text("☐ \(item.owner.map { "\($0): " } ?? "")\(item.text)")
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct RenameSpeakerSheet: View {
    let speaker: Speaker
    let onSave: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var company = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quem é esse participante?")
                .font(.headline)
            TextField("Nome", text: $name)
            TextField("Empresa (opcional)", text: $company)
            Text("O Ouvi vai reconhecer essa voz nas próximas reuniões — o perfil de voz fica só no seu Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Salvar") {
                    onSave(name, company)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            name = speaker.name.hasPrefix("Participante ") ? "" : speaker.name
            company = speaker.company ?? ""
        }
    }
}
