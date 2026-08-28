const SURFACES = [
  { id: "main", label: "Janela principal", Comp: MainWindow, chrome: true },
  { id: "search", label: "Busca + chat", Comp: SearchChat, chrome: true },
  { id: "person", label: "Pessoa", Comp: PersonPage, chrome: true },
  { id: "settings", label: "Ajustes", Comp: Settings, chrome: true, small: true },
  { id: "onboarding", label: "Onboarding", Comp: Onboarding, chrome: true, small: true },
  { id: "menubar", label: "Menu bar", Comp: MenuBarPanel, chrome: false },
  { id: "dictation", label: "Ditado", Comp: DictationHUD, chrome: false },
];

function Kit() {
  const [id, setId] = React.useState("main");
  const [dark, setDark] = React.useState(false);
  const s = SURFACES.find(x => x.id === id);

  React.useEffect(() => {
    document.documentElement.setAttribute("data-theme", dark ? "dark" : "light");
  }, [dark]);

  const width = s.small ? 900 : 1360;
  const height = s.small ? 620 : 700;

  return (
    <div style={{ minHeight: "100vh", padding: "var(--space-6)", display: "flex", flexDirection: "column", alignItems: "center", gap: "var(--space-5)" }}>
      <div style={{ display: "flex", alignItems: "center", gap: "var(--space-4)", flexWrap: "wrap", justifyContent: "center" }}>
        <SegmentedControl options={SURFACES.map(x => ({ value: x.id, label: x.label }))} value={id} onChange={setId} />
        <IconButton icon={dark ? "sun" : "moon"} title="Alternar tema" onClick={() => setDark(!dark)} />
      </div>

      <div style={{ width, height, borderRadius: "var(--radius-window)", overflow: "hidden", boxShadow: "var(--shadow-sheet)", background: "var(--bg-window)", display: "flex", flexDirection: "column" }}>
        {s.chrome ? (
          <div style={{ height: "var(--titlebar-height)", flex: "0 0 auto", display: "flex", alignItems: "center", gap: 8, padding: "0 12px", background: "var(--vibrancy-tint)", backdropFilter: "var(--blur-vibrancy)", borderBottom: "1px solid var(--border-hairline)" }}>
            {["#ff5f57","#febc2e","#28c840"].map(c => <span key={c} style={{ width: 11, height: 11, borderRadius: "50%", background: c }} />)}
            <span style={{ marginLeft: 8, font: "var(--type-caption)", color: "var(--text-muted)" }}>{s.label}</span>
          </div>
        ) : null}
        <div style={{ flex: 1, minHeight: 0 }}>
          <s.Comp />
        </div>
      </div>

      <div style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)" }}>
        recriação estática · dados fictícios · componentes de components/
      </div>
    </div>
  );
}
