import SwiftUI
import OuviKit
import GRDB

/// The kit's PersonPage: everything you ever discussed with one person —
/// display-size name, mono stats, "o que vocês discutem", open items, history,
/// and the Prep me / voice cards.
struct PersonPageView: View {
    @EnvironmentObject var state: AppState
    let speakerID: String

    @State private var speaker: Speaker?
    @State private var meetings: [Session] = []
    @State private var discussion: String?
    @State private var prep: String?
    @State private var busy: String?

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let discussion {
                        section("O QUE VOCÊS DISCUTEM") {
                            CitationText(text: discussion)
                        }
                    }
                    openItems
                    history
                }
                sideColumn
                    .frame(width: 280)
            }
            .padding(32)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DS.bgSurface)
        .task(id: speakerID) { load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(speaker?.name ?? "")
                .font(DS.sans(34, .bold))
                .tracking(-0.8)
                .foregroundStyle(DS.textTitle)
            HStack(spacing: 6) {
                if let company = speaker?.company {
                    TagView(icon: "building.2", label: company)
                }
                if speaker?.voiceCentroid != nil {
                    TagView(icon: "waveform", label: "voz identificada")
                }
            }
            Text(statsLine)
                .font(DS.monoXS)
                .foregroundStyle(DS.textFaint)
        }
    }

    private var statsLine: String {
        var parts = ["\(meetings.count) reuniões"]
        let minutes = meetings.compactMap { session -> Int? in
            guard let end = session.endedAt else { return nil }
            return Int(end.timeIntervalSince(session.startedAt) / 60)
        }.reduce(0, +)
        if minutes > 0 {
            parts.append(minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min")
        }
        if let first = meetings.last {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pt_BR")
            formatter.dateFormat = "d MMM"
            parts.append("primeira em \(formatter.string(from: first.startedAt))")
        }
        return parts.joined(separator: " · ")
    }

    private var openItems: some View {
        let items = collectOpenItems()
        return Group {
            if !items.isEmpty {
                section("PENDÊNCIAS ABERTAS") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(items.indices, id: \.self) { i in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "square")
                                    .font(.system(size: 10))
                                    .foregroundStyle(DS.textFaint)
                                    .padding(.top, 3)
                                Text(items[i])
                                    .font(DS.reading)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DS.bgSurface, in: RoundedRectangle(cornerRadius: DS.radiusCard))
                    .overlay(RoundedRectangle(cornerRadius: DS.radiusCard).strokeBorder(DS.borderHairline, lineWidth: 0.5))
                }
            }
        }
    }

    private var history: some View {
        section("HISTÓRICO") {
            VStack(spacing: 1) {
                ForEach(meetings) { session in
                    SessionRow(session: session, selected: false)
                        .onTapGesture {
                            state.selectedSessionID = session.id
                            state.nav = .all
                        }
                }
            }
        }
    }

    private var sideColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Antes da próxima")
                    .font(DS.bodyMedium)
                Text("Brief de 1 minuto com o histórico, pendências e o tom das últimas conversas.")
                    .font(DS.caption)
                    .foregroundStyle(DS.textMuted)
                if let prep {
                    CitationText(text: prep)
                        .foregroundStyle(DS.textBody)
                }
                HStack {
                    PrimaryButton(title: prep == nil ? "Prep me" : "Refazer", icon: "sparkles") { prepMe() }
                    if busy == "prep" { ProgressView().controlSize(.small) }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.bgSurface, in: RoundedRectangle(cornerRadius: DS.radiusCard))
            .overlay(RoundedRectangle(cornerRadius: DS.radiusCard).strokeBorder(DS.borderHairline, lineWidth: 0.5))

            if speaker?.voiceCentroid != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Voz")
                        .font(DS.bodyMedium)
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .foregroundStyle(DS.speakerColor(for: speakerID))
                        Text("embedding local")
                            .font(DS.monoXS)
                            .foregroundStyle(DS.textFaint)
                    }
                    Text("Reuniões futuras já chegam com o nome. A voz nunca sai do Mac.")
                        .font(DS.caption)
                        .foregroundStyle(DS.textMuted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.bgInset, in: RoundedRectangle(cornerRadius: DS.radiusCard))
            }

            PrivacyBadge(mode: .local, detail: "página gerada do vault")
        }
    }

    private func section(_ micro: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(micro)
                .font(DS.mono(10, .bold))
                .tracking(1.0)
                .foregroundStyle(DS.textFaint)
            content()
        }
    }

    // MARK: Data

    private func load() {
        speaker = try? state.database.pool.read { try Speaker.fetchOne($0, key: speakerID) }
        meetings = (try? state.database.sessions(withSpeaker: speakerID)) ?? []
        if discussion == nil, !meetings.isEmpty {
            summarizeDiscussion()
        }
    }

    private func collectOpenItems() -> [String] {
        guard let name = speaker?.name else { return [] }
        var items: [String] = []
        for session in meetings.prefix(6) {
            guard let json = session.summaryJSON?.data(using: .utf8),
                  let summary = try? JSONDecoder().decode(MeetingSummary.self, from: json)
            else { continue }
            for item in summary.actionItems
            where item.owner?.localizedCaseInsensitiveContains(name) == true
                || item.text.localizedCaseInsensitiveContains(name) {
                items.append("\(item.owner.map { "\($0) — " } ?? "")\(item.text)")
            }
        }
        return Array(items.prefix(8))
    }

    private func summarizeDiscussion() {
        guard busy == nil else { return }
        busy = "discussion"
        Task {
            defer { busy = nil }
            let name = speaker?.name ?? ""
            let intelligence = MeetingIntelligence(database: state.database)
            discussion = try? await intelligence.chat(
                sessionID: nil,
                question: "Em 2-3 frases, resuma os principais temas que eu discuto com \(name) nas minhas reuniões, com citações.")
        }
    }

    private func prepMe() {
        busy = "prep"
        Task {
            defer { busy = nil }
            let name = speaker?.name ?? ""
            let intelligence = MeetingIntelligence(database: state.database)
            do {
                prep = try await intelligence.chat(
                    sessionID: nil,
                    question: "Prepare um brief de 1 minuto para minha próxima reunião com \(name): contexto do relacionamento, pendências abertas de cada lado, e o que confirmar. Bullets curtos.")
            } catch {
                state.lastError = error.localizedDescription
            }
        }
    }
}
