import SwiftUI
import OuviKit
import GRDB

/// Personal dictionary: proper nouns the ASR must respect and spoken→written
/// replacements, applied in dictation cleanup and summary prompts.
struct DictionarySettings: View {
    @EnvironmentObject var state: AppState
    @State private var entries: [DictionaryEntry] = []
    @State private var newPhrase = ""
    @State private var newReplacement = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nomes, jargões e substituições que o Ouvi deve respeitar ao transcrever e ditar (ex.: \"pipa\" → \"Pipa\", \"girobase\" → \"Girobase\").")
                .font(.caption)
                .foregroundStyle(.secondary)

            Table(entries) {
                TableColumn("Termo") { entry in Text(entry.phrase) }
                TableColumn("Substituir por") { entry in
                    Text(entry.replacement ?? "— (proteger grafia)")
                        .foregroundStyle(entry.replacement == nil ? .secondary : .primary)
                }
                TableColumn("") { entry in
                    Button(role: .destructive) {
                        remove(entry)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .width(30)
            }

            HStack {
                TextField("Termo falado", text: $newPhrase)
                TextField("Substituição (vazio = só proteger)", text: $newReplacement)
                Button("Adicionar") { add() }
                    .disabled(newPhrase.isEmpty)
            }
        }
        .padding()
        .onAppear(perform: reload)
    }

    private func reload() {
        entries = (try? state.database.pool.read {
            try DictionaryEntry.order(Column("created_at")).fetchAll($0)
        }) ?? []
    }

    private func add() {
        let entry = DictionaryEntry(
            phrase: newPhrase.trimmingCharacters(in: .whitespaces),
            replacement: newReplacement.isEmpty ? nil : newReplacement)
        try? state.database.pool.write { try entry.insert($0) }
        newPhrase = ""
        newReplacement = ""
        reload()
    }

    private func remove(_ entry: DictionaryEntry) {
        _ = try? state.database.pool.write { try entry.delete($0) }
        reload()
    }
}
