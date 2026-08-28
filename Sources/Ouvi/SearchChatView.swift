import SwiftUI
import OuviKit
import GRDB

/// "Conversar com o histórico" — the kit's SearchChat: ask across every
/// meeting, get an answer with citation chips, see the retrieved excerpts and
/// related meetings, plus recipe shortcuts.
struct SearchChatView: View {
    @EnvironmentObject var state: AppState
    @State private var question = ""
    @State private var answer: String?
    @State private var excerpts: [TranscriptSegment] = []
    @State private var busy = false
    @State private var usedCloud = false

    private static let recipes: [(label: String, prompt: String)] = [
        ("Resumo da semana", "Resuma o que aconteceu nas minhas reuniões dos últimos 7 dias: decisões, temas recorrentes e pendências, em bullets curtos."),
        ("O que ficou pendente?", "Liste os action items e compromissos das reuniões recentes que aparentemente ainda não foram concluídos, com dono e reunião de origem."),
        ("Follow-up por email", "Escreva um rascunho de email de follow-up da reunião mais recente: contexto em 1 frase, decisões, action items com donos."),
        ("Prep me para a próxima", "Considerando meu histórico de reuniões, prepare um brief de 1 minuto para minha próxima reunião: contexto, pendências abertas e o que confirmar."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.textFaint)
                    TextField("Buscar ou perguntar sobre todas as suas reuniões", text: $question)
                        .textFieldStyle(.plain)
                        .font(DS.reading)
                        .onSubmit { ask(question) }
                    if busy {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Perguntar") { ask(question) }
                            .disabled(question.isEmpty)
                    }
                }
                .padding(12)
                .background(DS.bgInset, in: RoundedRectangle(cornerRadius: DS.radiusCard))
                .overlay(RoundedRectangle(cornerRadius: DS.radiusCard).strokeBorder(DS.borderHairline, lineWidth: 0.5))

                if let answer {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("RESPOSTA")
                            .font(DS.mono(10, .bold))
                            .tracking(1.0)
                            .foregroundStyle(DS.textFaint)
                        CitationText(text: answer)
                        HStack(spacing: 10) {
                            PrivacyBadge(
                                mode: usedCloud ? .cloud : .local,
                                detail: usedCloud
                                    ? "resposta pela Claude API · busca e trechos locais"
                                    : "resposta pelo LLM local")
                            GhostButton(title: "Copiar", icon: "doc.on.doc") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(answer, forType: .string)
                            }
                        }
                    }
                }

                if !excerpts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TRECHOS USADOS · FTS5")
                            .font(DS.mono(10, .bold))
                            .tracking(1.0)
                            .foregroundStyle(DS.textFaint)
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(excerpts, id: \.id) { excerpt in
                                ExcerptRow(excerpt: excerpt)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.bgInset, in: RoundedRectangle(cornerRadius: DS.radiusCard))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    if answer == nil {
                        Text("RECIPES")
                            .font(DS.mono(10, .bold))
                            .tracking(1.0)
                            .foregroundStyle(DS.textFaint)
                    }
                    HStack(spacing: 8) {
                        ForEach(Self.recipes, id: \.label) { recipe in
                            Button {
                                question = recipe.label
                                ask(recipe.prompt)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "sparkles").font(.system(size: 10))
                                    Text(recipe.label).font(DS.caption)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(DS.bgInset, in: Capsule())
                                .overlay(Capsule().strokeBorder(DS.borderHairline, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                            .disabled(busy)
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DS.bgSurface)
    }

    private func ask(_ prompt: String) {
        guard !prompt.isEmpty else { return }
        busy = true
        answer = nil
        Task {
            defer { busy = false }
            let intelligence = MeetingIntelligence(database: state.database)
            excerpts = (try? intelligence.retrievedSegments(for: prompt)) ?? []
            do {
                let backend = LLMRouter.backend()
                usedCloud = backend.isCloud
                answer = try await intelligence.chat(sessionID: nil, question: prompt)
            } catch {
                state.lastError = error.localizedDescription
            }
        }
    }
}

struct ExcerptRow: View {
    @EnvironmentObject var state: AppState
    let excerpt: TranscriptSegment

    var body: some View {
        Button {
            state.openCitation(sessionRef: String(excerpt.sessionID.prefix(8)), ms: excerpt.startMs)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(state.sessions.first { $0.id == excerpt.sessionID }?.title ?? "Reunião")
                        .font(DS.sans(11, .medium))
                        .foregroundStyle(DS.textMuted)
                        .lineLimit(1)
                    TimeCode(ms: excerpt.startMs)
                }
                Text(excerpt.text)
                    .font(DS.caption)
                    .foregroundStyle(DS.textBody)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
