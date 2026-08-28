function SearchChat() {
  const [q, setQ] = React.useState("o que discuti com o Eric sobre preço?");
  return (
    <div style={{ height: "100%", background: "var(--bg-window)", position: "relative", display: "flex", flexDirection: "column" }}>
      <div style={{ position: "absolute", inset: 0, background: "var(--bg-scrim)" }} />
      <div style={{ position: "relative", margin: "48px auto 0", width: 720, background: "var(--bg-surface)", borderRadius: "var(--radius-sheet)", boxShadow: "var(--shadow-sheet)", overflow: "hidden", display: "flex", flexDirection: "column", maxHeight: "calc(100% - 96px)" }}>
        <div style={{ padding: "var(--space-4)", borderBottom: "1px solid var(--border-hairline)", display: "flex", gap: "var(--space-3)", alignItems: "center" }}>
          <SearchField value={q} onChange={e => setQ(e.target.value)} placeholder="Buscar ou perguntar" shortcut={["⏎"]} />
          <SegmentedControl size="sm" options={["Buscar","Perguntar"]} value="Perguntar" onChange={() => {}} />
        </div>

        <div style={{ padding: "var(--space-6)", overflow: "hidden", display: "flex", flexDirection: "column", gap: "var(--space-6)" }}>
          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
            <div style={{ font: "var(--type-micro)", textTransform: "uppercase", letterSpacing: "var(--tracking-label)", color: "var(--text-faint)" }}>Resposta</div>
            <div style={{ font: "var(--type-reading)", maxWidth: "62ch" }}>
              Vocês falaram de preço três vezes. Em junho o Eric disse que qualquer contrato acima de 50k precisa de comitê<Citation time="09:14" />; em julho ele pediu preço por time, não por assento<Citation time="21:40" />; e hoje ele topou um piloto de 60 dias antes de discutir valor, desde que rode on-prem.<Citation time="14:41" />
            </div>
            <div style={{ display: "flex", gap: "var(--space-3)", alignItems: "center" }}>
              <PrivacyBadge mode="cloud" detail="resposta pela Claude API · busca e trechos locais" />
              <Button size="sm" variant="ghost" icon="file-text">Salvar como nota</Button>
            </div>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
            <div style={{ font: "var(--type-micro)", textTransform: "uppercase", letterSpacing: "var(--tracking-label)", color: "var(--text-faint)" }}>Trechos usados · FTS5 + vetorial</div>
            <Card inset padding="sm">
              <TranscriptLine speaker="Eric" slot={1} time="00:09:14" text="Acima de cinquenta mil eu preciso levar pro comitê, e aí entra jurídico." onSeek={() => {}} />
              <TranscriptLine speaker="Eric" slot={1} time="00:21:40" text="Preferimos preço por time. Por assento a gente não consegue prever o custo." onSeek={() => {}} />
            </Card>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
            <div style={{ font: "var(--type-micro)", textTransform: "uppercase", letterSpacing: "var(--tracking-label)", color: "var(--text-faint)" }}>Reuniões relacionadas</div>
            <SessionRow title="1:1 — Eric" when="ontem 09:30" duration="24 min" speakers="2 falantes" cloud />
            <SessionRow title="Superior Grocers — proposta v2" when="12 jul" duration="47 min" speakers="4 falantes" />
          </div>

          <div style={{ display: "flex", gap: "var(--space-2)", flexWrap: "wrap" }}>
            {["Prep me para a próxima","Follow-up por email","Resumo da semana","O que ficou pendente?"].map(r => (
              <Button key={r} size="sm" variant="secondary" icon="sparkles">{r}</Button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
