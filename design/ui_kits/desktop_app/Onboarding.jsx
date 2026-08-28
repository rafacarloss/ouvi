const PERMS = [
  { icon: "mic", name: "Microfone", why: "capta sua voz na reunião e no ditado", state: "ok" },
  { icon: "audio-lines", name: "Gravação de áudio do sistema", why: "capta a outra ponta da call, sem bot", state: "ok" },
  { icon: "keyboard", name: "Acessibilidade", why: "insere o texto ditado no app em foco", state: "pending" },
  { icon: "calendar", name: "Calendários", why: "sugere gravar quando a reunião começa", state: "pending" },
];

function Onboarding() {
  const [granted, setGranted] = React.useState({ 0: true, 1: true });
  const done = Object.values(granted).filter(Boolean).length;
  return (
    <div style={{ height: "100%", background: "var(--bg-window)", display: "flex", alignItems: "center", justifyContent: "center", padding: "var(--space-9)" }}>
      <div style={{ width: 620, display: "flex", flexDirection: "column", gap: "var(--space-7)" }}>
        <div>
          <div style={{ display: "flex", alignItems: "center", gap: 7, marginBottom: "var(--space-5)" }}>
            <span style={{ fontFamily: "var(--font-sans)", fontWeight: 900, fontSize: 22, letterSpacing: "-0.03em", color: "var(--text-title)" }}>ouvi</span>
            <span style={{ width: 6, height: 6, borderRadius: "50%", background: "var(--live)", marginTop: 7 }} />
          </div>
          <h1 style={{ font: "var(--type-title-1)", letterSpacing: "var(--tracking-title)", color: "var(--text-title)" }}>Quatro permissões e você está pronto</h1>
          <p style={{ font: "var(--type-reading)", color: "var(--text-muted)", marginTop: "var(--space-3)", maxWidth: "56ch" }}>
            O macOS pede cada uma separadamente. Nada é enviado para fora do seu Mac — as permissões existem para captar áudio e colar o texto ditado.
          </p>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
          {PERMS.map((p, i) => {
            const ok = Boolean(granted[i]);
            return (
              <Card key={p.name} padding="sm">
                <div style={{ display: "flex", alignItems: "center", gap: "var(--space-4)" }}>
                  <span style={{ width: 30, height: 30, borderRadius: "var(--radius-md)", background: ok ? "var(--accent-soft)" : "var(--bg-inset)", color: ok ? "var(--accent-soft-text)" : "var(--text-faint)", display: "inline-flex", alignItems: "center", justifyContent: "center" }}>
                    <Icon name={p.icon} size={16} />
                  </span>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ font: "var(--type-ui-medium)" }}>{p.name}</div>
                    <div style={{ font: "var(--type-caption)", color: "var(--text-muted)" }}>{p.why}</div>
                  </div>
                  {ok ? (
                    <Badge tone="local">concedida</Badge>
                  ) : (
                    <Button size="sm" variant="secondary" onClick={() => setGranted({ ...granted, [i]: true })}>Permitir</Button>
                  )}
                </div>
              </Card>
            );
          })}
        </div>

        <Card padding="md" inset>
          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: "var(--space-4)" }}>
              <div>
                <div style={{ font: "var(--type-ui-medium)" }}>Onde ficam suas notas</div>
                <div style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)", marginTop: 3 }}>~/Ouvi</div>
              </div>
              <Button size="sm" variant="secondary" icon="folder">Escolher pasta</Button>
            </div>
            <ProgressBar value={done * 25} label="Baixando parakeet-tdt-0.6b-v3 e o modelo de diarização" detail={(done * 300) + " MB / 1,2 GB"} />
          </div>
        </Card>

        <div style={{ display: "flex", alignItems: "center", gap: "var(--space-4)" }}>
          <Button variant="primary" size="lg" iconRight="chevron-right" disabled={done < 4}>Começar</Button>
          <span style={{ font: "var(--type-caption)", color: "var(--text-muted)" }}>{done}/4 permissões · sem conta, sem login, sem telemetria</span>
        </div>
      </div>
    </div>
  );
}
