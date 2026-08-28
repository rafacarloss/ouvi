import Foundation

/// Summary templates: section headings act as prompt cues (the Granola trick —
/// a "Citações" section pulls verbatim quotes, "Action items" pulls commitments).
/// Custom templates are plain Markdown files in `<vault>/Templates/*.md`:
/// first line `# Nome do template`, then one `## Seção` per section.
public struct SummaryTemplate: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let sections: [String]

    public init(id: String, name: String, sections: [String]) {
        self.id = id
        self.name = name
        self.sections = sections
    }

    public static let builtins: [SummaryTemplate] = [
        SummaryTemplate(id: "auto", name: "Automático", sections: []),
        SummaryTemplate(
            id: "discovery", name: "Discovery call",
            sections: ["Contexto do cliente", "Dores e problemas relatados", "Processo atual",
                       "Objeções e riscos", "Citações marcantes", "Próximos passos"]),
        SummaryTemplate(
            id: "one-on-one", name: "1:1",
            sections: ["Como a pessoa está", "Progresso desde a última conversa",
                       "Bloqueios", "Feedback trocado", "Combinados"]),
        SummaryTemplate(
            id: "user-research", name: "Entrevista de usuário",
            sections: ["Perfil do entrevistado", "Comportamento atual", "Dores",
                       "Reações ao produto", "Citações verbatim", "Insights"]),
        SummaryTemplate(
            id: "standup", name: "Standup",
            sections: ["Feito", "Fazendo", "Bloqueios"]),
        SummaryTemplate(
            id: "sales", name: "Call de vendas",
            sections: ["Situação e contexto", "Necessidade e urgência", "Orçamento e decisor",
                       "Concorrência", "Objeções", "Próximos passos e prazos"]),
        SummaryTemplate(
            id: "board", name: "Reunião de sócios/board",
            sections: ["Métricas e status", "Decisões tomadas", "Discussões em aberto",
                       "Riscos", "Action items"]),
    ]

    /// Custom templates from the vault, merged after the builtins.
    public static func all() -> [SummaryTemplate] {
        builtins + custom()
    }

    public static func custom() -> [SummaryTemplate] {
        let dir = OuviSettings.vaultURL.appendingPathComponent("Templates", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)
        else { return [] }
        return files
            .filter { $0.pathExtension == "md" }
            .compactMap { url -> SummaryTemplate? in
                guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                var name = url.deletingPathExtension().lastPathComponent
                var sections: [String] = []
                for line in content.split(separator: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("## ") {
                        sections.append(String(trimmed.dropFirst(3)))
                    } else if trimmed.hasPrefix("# ") {
                        name = String(trimmed.dropFirst(2))
                    }
                }
                guard !sections.isEmpty else { return nil }
                return SummaryTemplate(id: "custom-\(url.lastPathComponent)", name: name, sections: sections)
            }
            .sorted { $0.name < $1.name }
    }
}
