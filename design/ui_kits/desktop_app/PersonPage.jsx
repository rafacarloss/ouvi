function PersonPage() {
  return (
    <div style={{ height: "100%", background: "var(--bg-surface)", overflow: "hidden", display: "flex", flexDirection: "column" }}>
      <Toolbar leading={<span style={{ font: "var(--type-ui-medium)" }}>Eric</span>} trailing={<span style={{ display: "flex", gap: 4 }}><IconButton icon="message-square" title="Perguntar sobre o Eric" /><IconButton icon="download" title="Exportar" /></span>}>
        <span style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)" }}>~/Ouvi/pessoas/eric.md</span>
      </Toolbar>
      <div style={{ padding: "var(--space-8)", display: "flex", gap: "var(--space-8)", overflow: "hidden" }}>
        <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", gap: "var(--space-7)" }}>
          <div>
            <h1 style={{ font: "var(--type-display)", letterSpacing: "var(--tracking-display)", color: "var(--text-title)" }}>Eric</h1>
            <div style={{ display: "flex", gap: "var(--space-3)", marginTop: "var(--space-4)", flexWrap: "wrap" }}>
              <Tag icon="building-2">Superior Grocers</Tag>
              <Tag icon="folder">Pipa</Tag>
              <Tag icon="user">voz identificada</Tag>
            </div>
            <div style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)", marginTop: "var(--space-4)" }}>9 reuniões · 6 h 12 min · primeira em 04 abr · última ontem</div>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
            <div style={{ font: "var(--type-micro)", textTransform: "uppercase", letterSpacing: "var(--tracking-label)", color: "var(--text-faint)" }}>O que vocês discutem</div>
            <div style={{ font: "var(--type-reading)", maxWidth: "60ch" }}>
              Preço por time em vez de assento<Citation time="21:40" />, exigência de dado on-prem<Citation time="13:58" /> e a mecânica do comitê interno acima de 50k.<Citation time="09:14" />
            </div>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
            <div style={{ font: "var(--type-micro)", textTransform: "uppercase", letterSpacing: "var(--tracking-label)", color: "var(--text-faint)" }}>Pendências abertas</div>
            <Card padding="md">
              <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)", font: "var(--type-reading)" }}>
                <Checkbox checked={false} onChange={() => {}} label="Enviar escopo do piloto de 60 dias (você, até sexta)" />
                <Checkbox checked={false} onChange={() => {}} label="Eric libera staging e leva ao comitê" />
                <Checkbox checked label="Mandar comparativo de preço por time" />
              </div>
            </Card>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-2)" }}>
            <div style={{ font: "var(--type-micro)", textTransform: "uppercase", letterSpacing: "var(--tracking-label)", color: "var(--text-faint)", marginBottom: 4 }}>Histórico</div>
            <SessionRow title="Discovery — Superior Grocers" when="hoje 14:00" duration="41 min" speakers="3 falantes" live />
            <SessionRow title="1:1 — Eric" when="ontem 09:30" duration="24 min" speakers="2 falantes" cloud />
            <SessionRow title="Superior Grocers — proposta v2" when="12 jul" duration="47 min" speakers="4 falantes" />
            <SessionRow title="Intro — Superior Grocers" when="04 abr" duration="31 min" speakers="3 falantes" />
          </div>
        </div>

        <div style={{ width: 280, flex: "0 0 auto", display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
          <Card padding="md">
            <div style={{ font: "var(--type-ui-medium)", marginBottom: "var(--space-3)" }}>Antes da próxima</div>
            <div style={{ font: "var(--type-caption)", color: "var(--text-muted)", lineHeight: 1.7 }}>
              Brief de 1 minuto com o histórico, pendências e o tom das últimas conversas.
            </div>
            <div style={{ marginTop: "var(--space-4)" }}><Button variant="primary" size="sm" icon="sparkles" fullWidth>Prep me</Button></div>
          </Card>
          <Card padding="md" inset>
            <div style={{ font: "var(--type-ui-medium)", marginBottom: "var(--space-3)" }}>Voz</div>
            <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)" }}>
              <Waveform bars={16} live={false} height={20} color="var(--speaker-a)" />
              <span style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)" }}>embedding local</span>
            </div>
            <div style={{ font: "var(--type-caption)", color: "var(--text-muted)", marginTop: "var(--space-3)" }}>
              Reuniões futuras já chegam com o nome dele. A voz nunca sai do Mac.
            </div>
          </Card>
          <PrivacyBadge mode="local" detail="página gerada do vault" />
        </div>
      </div>
    </div>
  );
}
