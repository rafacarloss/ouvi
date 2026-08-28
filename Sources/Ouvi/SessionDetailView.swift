import SwiftUI
import OuviKit
import GRDB

/// The kit's content pane: toolbar · tabs (Notas / Transcript / Resumo) ·
/// collapsible 340px transcript rail with live badge, waveform and player.
struct SessionDetailView: View {
    @EnvironmentObject var state: AppState
    let sessionID: String

    enum Tab: String, CaseIterable {
        case notas = "Notas"
        case transcript = "Transcript"
        case resumo = "Resumo"
    }

    @State private var tab: Tab = .notas
    @State private var showRail = true
    @State private var session: Session?
    @State private var segments: [TranscriptSegment] = []
    @State private var speakerNames: [String: String] = [:]
    @State private var notes: String = ""
    @State private var enhanced: String?
    @State private var summary: MeetingSummary?
    @State private var busy: String?
    @State private var renamingSpeaker: Speaker?
    @State private var followUpDraft: String?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(DS.borderHairline)
            HStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                if showRail {
                    Divider().overlay(DS.borderHairline)
                    TranscriptRail(
                        sessionID: sessionID,
                        session: session,
                        segments: segments,
                        speakerNames: speakerNames,
                        isLive: isLiveSession,
                        onRename: { beginRename($0) })
                        .frame(width: DS.transcriptWidth)
                }
            }
        }
        .background(DS.bgSurface)
        .task(id: sessionID) { load() }
        .onReceive(state.$processingStage) { stage in
            if stage == nil { load() }
        }
        .sheet(item: $renamingSpeaker) { speaker in
            RenameSpeakerSheet(speaker: speaker) { newName, company in
                rename(speaker: speaker, to: newName, company: company)
            }
        }
        .sheet(isPresented: Binding(
            get: { followUpDraft != nil },
            set: { if !$0 { followUpDraft = nil } })
        ) {
            FollowUpSheet(text: followUpDraft ?? "")
        }
    }

    private var isLiveSession: Bool {
        state.recording?.session.id == sessionID
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(session?.title ?? "Reunião")
                    .font(DS.bodyMedium)
                    .foregroundStyle(DS.textTitle)
                    .lineLimit(1)
                Text(metaLine)
                    .font(DS.monoXS)
                    .foregroundStyle(DS.textFaint)
            }
            Spacer()
            if session?.usedCloud == true {
                PrivacyBadge(mode: .cloud, detail: nil)
                    .help("Nuvem usada nesta reunião — apenas o texto do transcript foi enviado.")
            }
            IconAction(icon: "sparkles", help: "Melhorar notas", active: enhanced != nil) {
                enhance()
            }
            IconAction(icon: "waveform", help: "Transcript", active: showRail) {
                withAnimation(.easeOut(duration: 0.18)) { showRail.toggle() }
            }
            Menu {
                ForEach(ExportService.Format.allCases, id: \.rawValue) { format in
                    Button(format.rawValue.uppercased()) { export(format) }
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.textMuted)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(segments.isEmpty)
            .help("Exportar")
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    private var metaLine: String {
        var parts: [String] = []
        if let session {
            parts.append(SessionRow.relativeDate(session.startedAt))
            if let lang = session.language { parts.append(lang == "pt" ? "pt-BR" : lang) }
            if session.kind == .importedFile { parts.append("importado") }
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Content (tabs)

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                if !participantTags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(participantTags, id: \.id) { speaker in
                            TagView(icon: "person", label: speaker.name) {
                                state.nav = .person(speaker.id)
                            }
                        }
                    }
                }

                switch tab {
                case .notas: notasTab
                case .transcript: transcriptTab
                case .resumo: resumoTab
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: 640, alignment: .leading)
        }
        .background(DS.bgSurface)
    }

    private var participantTags: [Speaker] {
        let ids = Set(segments.compactMap(\.speakerID))
        return ids.compactMap { id in
            guard let name = speakerNames[id], !name.hasPrefix("Falante ") else { return nil }
            return Speaker(id: id, name: name)
        }
        .sorted { $0.name < $1.name }
    }

    // MARK: Notas

    private var notasTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session?.title ?? "")
                .font(DS.sans(19, .medium))
                .foregroundStyle(DS.textTitle)

            TextEditor(text: $notes)
                .font(DS.reading)
                .lineSpacing(4)
                .frame(minHeight: 140)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(DS.bgInset, in: RoundedRectangle(cornerRadius: DS.radiusCard))
                .overlay(RoundedRectangle(cornerRadius: DS.radiusCard).strokeBorder(DS.borderHairline, lineWidth: 0.5))
                .overlay(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("Suas anotações durante a call — bullets curtos bastam.")
                            .font(DS.reading)
                            .foregroundStyle(DS.textFaint)
                            .padding(14)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: notes) { _, new in
                    state.notesDrafts[sessionID] = new
                    state.saveNotes(sessionID: sessionID, userNotes: new, enhancedNotes: nil)
                }

            if let enhanced {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Self.enhancedLines(enhanced), id: \.self) { line in
                        CitationText(text: line)
                            .foregroundStyle(DS.textMuted)
                    }
                }
                HStack(spacing: 12) {
                    PrivacyBadge(
                        mode: session?.usedCloud == true ? .cloud : .local,
                        detail: session?.usedCloud == true
                            ? "notas pela Claude API — só o texto do transcript foi enviado"
                            : "notas pelo LLM local")
                    GhostButton(title: "Refazer", icon: "sparkles") { enhance() }
                }
            } else {
                HStack(spacing: 12) {
                    PrimaryButton(title: "Melhorar notas", icon: "sparkles") { enhance() }
                    Text("suas linhas ficam como estão; as adições da IA entram em cinza, com citação")
                        .font(DS.caption)
                        .foregroundStyle(DS.textMuted)
                }
                .disabled(busy != nil || segments.isEmpty)
            }
            if let busy {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(busy).font(DS.caption).foregroundStyle(DS.textMuted)
                }
            }
            if isLiveSession {
                WhatDidIMissCard()
            }
        }
    }

    static func enhancedLines(_ text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: true)
            .map { line in
                var l = line.trimmingCharacters(in: .whitespaces)
                if l.hasPrefix("- ") || l.hasPrefix("* ") { l = "–  " + l.dropFirst(2) }
                return l
            }
    }

    // MARK: Transcript tab (reading column)

    private var transcriptTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            if segments.isEmpty && !isLiveSession {
                Text(session?.state == .transcribing ? "Transcrevendo…" : "Sem transcrição ainda.")
                    .font(DS.body)
                    .foregroundStyle(DS.textFaint)
            }
            if isLiveSession { LiveTranscriptView() }
            ForEach(segments) { segment in
                TranscriptLineView(
                    segment: segment,
                    speakerName: name(for: segment),
                    onRename: { beginRename(segment) },
                    onSeek: { seek(toMs: segment.startMs) })
            }
        }
    }

    // MARK: Resumo tab

    private var resumoTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let summary {
                CitationText(text: summary.overview)
                    .foregroundStyle(DS.textMuted)
                ForEach(summary.topics.indices, id: \.self) { i in
                    SummaryCard(micro: summary.topics[i].heading.uppercased()) {
                        ForEach(summary.topics[i].bullets.indices, id: \.self) { j in
                            CitationText(text: summary.topics[i].bullets[j])
                        }
                    }
                }
                if !summary.decisions.isEmpty {
                    SummaryCard(micro: "DECISÕES") {
                        ForEach(summary.decisions.indices, id: \.self) { i in
                            CitationText(text: summary.decisions[i])
                        }
                    }
                }
                if !summary.actionItems.isEmpty {
                    SummaryCard(micro: "ACTION ITEMS") {
                        ForEach(summary.actionItems.indices, id: \.self) { i in
                            let item = summary.actionItems[i]
                            CitationText(text: "\(item.owner.map { "\($0) — " } ?? "")\(item.text)")
                        }
                    }
                }
                HStack(spacing: 8) {
                    GhostButton(title: "Rascunho de follow-up", icon: "doc.text") { followUp() }
                    Menu {
                        ForEach(SummaryTemplate.all()) { template in
                            Button(template.name) { summarize(with: template) }
                        }
                    } label: {
                        Text("Refazer com template")
                            .font(DS.body)
                            .foregroundStyle(DS.textMuted)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            } else {
                Menu {
                    ForEach(SummaryTemplate.all()) { template in
                        Button(template.name) { summarize(with: template) }
                    }
                } label: {
                    Label("Resumir", systemImage: "text.badge.star")
                        .font(DS.bodyMedium)
                } primaryAction: {
                    summarize(with: nil)
                }
                .fixedSize()
                .disabled(busy != nil || segments.isEmpty)
                Text("Tópicos, decisões e action items — com citação para o momento exato.")
                    .font(DS.caption)
                    .foregroundStyle(DS.textMuted)
            }
            if let busy {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(busy).font(DS.caption).foregroundStyle(DS.textMuted)
                }
            }
        }
    }

    // MARK: Data + actions

    private func load() {
        session = try? state.database.session(id: sessionID)
        segments = (try? state.database.segments(sessionID: sessionID)) ?? []
        let speakers = (try? state.database.pool.read { try Speaker.fetchAll($0) }) ?? []
        speakerNames = Dictionary(uniqueKeysWithValues: speakers.map { ($0.id, $0.name) })
        if notes.isEmpty {
            notes = state.notesDrafts[sessionID] ?? session?.userNotes ?? ""
        }
        if enhanced == nil {
            enhanced = session?.enhancedNotes
        }
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

    private func enhance() {
        guard !notes.isEmpty else {
            state.lastError = "Escreva algumas linhas de notas primeiro — elas guiam o que a IA completa."
            return
        }
        run("Melhorando notas…") {
            let intelligence = MeetingIntelligence(database: state.database)
            enhanced = try await intelligence.enhanceNotes(sessionID: sessionID, userNotes: notes)
            state.saveNotes(sessionID: sessionID, userNotes: notes, enhancedNotes: enhanced)
            persistNote()
            load()
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

    private func followUp() {
        run("Escrevendo follow-up…") {
            let intelligence = MeetingIntelligence(database: state.database)
            followUpDraft = try await intelligence.chat(
                sessionID: sessionID,
                question: "Escreva um email de follow-up curto e direto desta reunião, no idioma dela: contexto em 1 frase, o que foi decidido, action items com donos e prazos. Sem citações no texto.")
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
        state.refreshSessions()
        persistNote()
    }

    private func seek(toMs ms: Int) {
        guard let session else { return }
        state.audioPlayer.play(session: session, atMs: ms)
    }
}

// MARK: - Transcript line (kit's TranscriptLine)

struct TranscriptLineView: View {
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

// MARK: - Transcript rail

struct TranscriptRail: View {
    @EnvironmentObject var state: AppState
    @ObservedObject private var player: AudioPlayerController
    let sessionID: String
    let session: Session?
    let segments: [TranscriptSegment]
    let speakerNames: [String: String]
    let isLive: Bool
    let onRename: (TranscriptSegment) -> Void

    init(
        sessionID: String, session: Session?, segments: [TranscriptSegment],
        speakerNames: [String: String], isLive: Bool,
        onRename: @escaping (TranscriptSegment) -> Void
    ) {
        self.sessionID = sessionID
        self.session = session
        self.segments = segments
        self.speakerNames = speakerNames
        self.isLive = isLive
        self.onRename = onRename
        _player = ObservedObject(wrappedValue: AppState.shared.audioPlayer)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if isLive {
                    HStack(spacing: 6) {
                        Circle().fill(DS.live).frame(width: 7, height: 7)
                        Text("ao vivo · \(elapsed)")
                            .font(DS.mono(11, .bold))
                            .foregroundStyle(DS.accentSoftText)
                    }
                } else {
                    Text("TRANSCRIPT")
                        .font(DS.mono(10, .bold))
                        .tracking(1.0)
                        .foregroundStyle(DS.textFaint)
                }
                Spacer()
                if isLive {
                    WaveformView(level: max(state.micLevel, state.systemLevel))
                }
            }
            .padding(12)
            Divider().overlay(DS.borderHairline)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if isLive { LiveTranscriptView() }
                    ForEach(segments) { segment in
                        TranscriptLineView(
                            segment: segment,
                            speakerName: name(for: segment),
                            onRename: { onRename(segment) },
                            onSeek: { seek(toMs: segment.startMs) })
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().overlay(DS.borderHairline)
            VStack(alignment: .leading, spacing: 8) {
                if let session, session.state == .ready {
                    HStack(spacing: 10) {
                        Button {
                            player.toggle(session: session)
                        } label: {
                            Image(systemName: player.playingSessionID == session.id && player.isPlaying
                                  ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(DS.accent)
                        }
                        .buttonStyle(.plain)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(DS.borderHairline).frame(height: 3)
                                Capsule().fill(DS.accent)
                                    .frame(width: geo.size.width * (player.playingSessionID == session.id ? player.progress : 0), height: 3)
                            }
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                let fraction = location.x / max(1, geo.size.width)
                                let ms = Int(fraction * Double(player.playingSessionID == session.id ? Double(player.durationMs) : sessionDurationMs))
                                player.play(session: session, atMs: ms)
                            }
                        }
                        .frame(height: 20)
                        TimeCode(ms: player.playingSessionID == session.id ? player.currentMs : 0)
                    }
                }
                Text(isLive
                     ? "parakeet-tdt-0.6b-v3 · rascunho ao vivo · refino no encerramento"
                     : "parakeet-tdt-0.6b-v3 · transcrito neste Mac")
                    .font(DS.monoXS)
                    .foregroundStyle(DS.textFaint)
            }
            .padding(12)
        }
        .background(DS.bgInset)
    }

    private var elapsed: String {
        let s = Int(state.recordingElapsed)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private var sessionDurationMs: Double {
        Double(segments.last?.endMs ?? 0)
    }

    private func name(for segment: TranscriptSegment) -> String {
        switch segment.channel {
        case .me: return "Você"
        case .them: return segment.speakerID.flatMap { speakerNames[$0] } ?? "Falante"
        }
    }

    private func seek(toMs ms: Int) {
        guard let session else { return }
        player.play(session: session, atMs: ms)
    }
}

// MARK: - Live pieces

struct LiveTranscriptView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
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

/// "O que eu perdi?" — asks the LLM over the live draft so far.
struct WhatDidIMissCard: View {
    @EnvironmentObject var state: AppState
    @State private var answer: String?
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                GhostButton(title: "O que eu perdi?", icon: "questionmark.bubble") { ask() }
                if busy { ProgressView().controlSize(.small) }
            }
            if let answer {
                CitationText(text: answer)
                    .foregroundStyle(DS.textMuted)
            }
        }
    }

    private func ask() {
        let context = """
        [Eles] \(state.liveThem.confirmed)
        [Você] \(state.liveMe.confirmed)
        """
        busy = true
        Task {
            defer { busy = false }
            let backend = LLMRouter.backend()
            answer = try? await backend.complete(
                system: "Resuma em 3 bullets, no idioma da conversa, o que foi dito até agora nesta reunião em andamento. Seja factual e curto.",
                messages: [LLMMessage(role: "user", content: context)],
                maxTokens: 1024)
        }
    }
}

// MARK: - Small pieces

struct IconAction: View {
    let icon: String
    let help: String
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(active ? DS.accentSoftText : DS.textMuted)
                .frame(width: 26, height: 24)
                .background(active ? DS.accentSoft : .clear, in: RoundedRectangle(cornerRadius: DS.radiusControl))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct SummaryCard<Content: View>: View {
    let micro: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(micro)
                .font(DS.mono(10, .bold))
                .tracking(1.0)
                .foregroundStyle(DS.textFaint)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.bgSurface, in: RoundedRectangle(cornerRadius: DS.radiusCard))
        .overlay(RoundedRectangle(cornerRadius: DS.radiusCard).strokeBorder(DS.borderHairline, lineWidth: 0.5))
    }
}

struct FollowUpSheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rascunho de follow-up")
                .font(DS.title3)
            ScrollView {
                Text(text)
                    .font(DS.reading)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 200)
            HStack {
                Spacer()
                Button("Copiar") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                Button("Fechar") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520, height: 380)
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
            Text("Reuniões futuras já chegam com o nome. A voz nunca sai do Mac.")
                .font(DS.caption)
                .foregroundStyle(DS.textMuted)
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
