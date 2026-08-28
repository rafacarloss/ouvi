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
                    Label("Melhorar notas", systemImage: "sparkles")
                }
                .disabled(busy != nil || segments.isEmpty || notes.isEmpty)

                Menu {
                    ForEach(SummaryTemplate.all()) { template in
                        Button(template.name) { summarize(with: template) }
                    }
                } label: {
                    Label("Resumir", systemImage: "text.badge.star")
                } primaryAction: {
                    summarize(with: nil)
                }
                .fixedSize()
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
                Menu {
                    ForEach(ExportService.Format.allCases, id: \.rawValue) { format in
                        Button(format.rawValue.uppercased()) { export(format) }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(segments.isEmpty)
                .help("Exportar transcrição")
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
                    if isLiveSession {
                        LiveTranscriptView()
                    }
                    ForEach(segments) { segment in
                        SegmentView(
                            segment: segment,
                            speakerName: name(for: segment),
                            onRename: { beginRename(segment) },
                            onSeek: { seek(toMs: segment.startMs) })
                    }
                    if segments.isEmpty && !isLiveSession {
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

    private var isLiveSession: Bool {
        state.recording?.session.id == sessionID
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
        case .me: return "Você"
        case .them: return segment.speakerID.flatMap { speakerNames[$0] } ?? "Falante"
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

    private func summarize(with template: SummaryTemplate?) {
        run("Resumindo…") {
            let intelligence = MeetingIntelligence(database: state.database)
            summary = try await intelligence.summarize(
                sessionID: sessionID, userNotes: notes, template: template)
            persistNote()
            load()
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

    private func export(_ format: ExportService.Format) {
        guard let content = try? ExportService.export(
            sessionID: sessionID, format: format, database: state.database)
        else { return }
        let panel = NSSavePanel()
        let base = VaultWriter.slugify(session?.title ?? "reuniao")
        panel.nameFieldStringValue = "\(base).\(format.rawValue)"
        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
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

/// Draft transcript streamed while the meeting is still being recorded.
struct LiveTranscriptView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Circle().fill(DS.live).frame(width: 7, height: 7)
                MicroBadge(text: "RASCUNHO")
                Text("refinando ao final")
                    .font(DS.caption)
                    .foregroundStyle(DS.textFaint)
            }
            channelView(label: "Eles", text: state.liveThem)
            channelView(label: "Você", text: state.liveMe)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.bgSurface, in: RoundedRectangle(cornerRadius: DS.radiusCard))
        .overlay(RoundedRectangle(cornerRadius: DS.radiusCard).strokeBorder(DS.borderHairline, lineWidth: 0.5))
    }

    @ViewBuilder
    private func channelView(label: String, text: (confirmed: String, volatile: String)) -> some View {
        if !text.confirmed.isEmpty || !text.volatile.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DS.sans(12, .medium))
                    .foregroundStyle(DS.textMuted)
                (Text(text.confirmed).foregroundStyle(DS.textBody)
                    + Text(text.confirmed.isEmpty ? "" : " ")
                    + Text(text.volatile).foregroundStyle(DS.textDraft))
                    .font(DS.reading)
                    .lineSpacing(4)
            }
        }
    }
}

struct SegmentView: View {
    let segment: TranscriptSegment
    let speakerName: String
    let onRename: () -> Void
    let onSeek: () -> Void

    private var speakerColor: Color {
        segment.channel == .me ? DS.speakerMe : DS.speakerColor(for: segment.speakerID)
    }

    private var isUnnamed: Bool {
        segment.channel == .them && speakerName.hasPrefix("Falante")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 3px speaker rule — the only place speaker color appears.
            RoundedRectangle(cornerRadius: 1.5)
                .fill(speakerColor)
                .frame(width: 3)
                .padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(speakerName)
                        .font(DS.sans(12, .medium))
                        .foregroundStyle(DS.textMuted)
                        .onTapGesture(count: 2) { onRename() }
                    if isUnnamed {
                        Button("dar nome", action: onRename)
                            .buttonStyle(.plain)
                            .font(DS.caption)
                            .foregroundStyle(DS.accentHover)
                    }
                    Button(action: onSeek) {
                        TimeCode(ms: segment.startMs)
                    }
                    .buttonStyle(.plain)
                    .help("Ouvir este trecho")
                }
                Text(segment.text)
                    .font(DS.reading)
                    .foregroundStyle(segment.isDraft ? DS.textDraft : DS.textBody)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
        }
    }
}

struct SummaryView: View {
    let summary: MeetingSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary.overview)
                .font(DS.reading)
                .foregroundStyle(DS.textMuted)
                .lineSpacing(4)
            ForEach(summary.topics.indices, id: \.self) { i in
                let topic = summary.topics[i]
                VStack(alignment: .leading, spacing: 4) {
                    Text(topic.heading)
                        .font(DS.sans(13, .medium))
                        .foregroundStyle(DS.textTitle)
                    ForEach(topic.bullets.indices, id: \.self) { j in
                        Text("–  \(topic.bullets[j])")
                            .font(DS.body)
                            .foregroundStyle(DS.textBody)
                    }
                }
            }
            if !summary.actionItems.isEmpty {
                Text("Action items")
                    .font(DS.sans(13, .medium))
                    .foregroundStyle(DS.textTitle)
                ForEach(summary.actionItems.indices, id: \.self) { i in
                    let item = summary.actionItems[i]
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "square")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.textFaint)
                            .padding(.top, 3)
                        Text("\(item.owner.map { "\($0) — " } ?? "")\(item.text)")
                            .font(DS.body)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.bgSurface, in: RoundedRectangle(cornerRadius: DS.radiusCard))
        .overlay(RoundedRectangle(cornerRadius: DS.radiusCard).strokeBorder(DS.borderHairline, lineWidth: 0.5))
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
            Text("Quem está falando?")
                .font(DS.title3)
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
            name = speaker.name.hasPrefix("Falante ") ? "" : speaker.name
            company = speaker.company ?? ""
        }
    }
}
