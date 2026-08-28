function Site() {
  const [page, setPage] = React.useState("Início");
  const [dark, setDark] = React.useState(false);
  React.useEffect(() => {
    document.documentElement.setAttribute("data-theme", dark ? "dark" : "light");
  }, [dark]);

  return (
    <div style={{ minHeight: "100vh", background: "var(--bg-window)" }}>
      <header style={{ position: "sticky", top: 0, zIndex: 10, background: "var(--vibrancy-tint)", backdropFilter: "var(--blur-vibrancy)", borderBottom: "1px solid var(--border-hairline)" }}>
        <div style={{ maxWidth: "var(--site-max)", margin: "0 auto", padding: "var(--space-4) var(--space-7)", display: "flex", alignItems: "center", gap: "var(--space-6)" }}>
          <span style={{ display: "inline-flex", alignItems: "center", gap: 6 }}>
            <span style={{ fontFamily: "var(--font-sans)", fontWeight: 900, fontSize: 19, letterSpacing: "-0.03em", color: "var(--text-title)" }}>ouvi</span>
            <span style={{ width: 5, height: 5, borderRadius: "50%", background: "var(--live)", marginTop: 6 }} />
          </span>
          <nav style={{ display: "flex", gap: "var(--space-5)", flex: 1 }}>
            {["Início","Docs"].map(l => (
              <a key={l} href="#" onClick={e => { e.preventDefault(); setPage(l); }}
                 style={{ font: page === l ? "var(--type-ui-medium)" : "var(--type-ui)", color: page === l ? "var(--text-body)" : "var(--text-muted)", textDecoration: "none" }}>
                {l}
              </a>
            ))}
          </nav>
          <IconButton icon={dark ? "sun" : "moon"} title="Alternar tema" onClick={() => setDark(!dark)} />
          <Button variant="secondary" size="sm" icon="github">GitHub</Button>
          <Button variant="primary" size="sm" icon="download">Baixar</Button>
        </div>
      </header>

      {page === "Início" ? <Landing /> : <Docs />}

      <footer style={{ borderTop: "1px solid var(--border-hairline)", background: "var(--bg-sidebar)" }}>
        <div style={{ maxWidth: "var(--site-max)", margin: "0 auto", padding: "var(--space-8) var(--space-7)", display: "flex", gap: "var(--space-9)", flexWrap: "wrap", justifyContent: "space-between" }}>
          <div style={{ maxWidth: "36ch" }}>
            <span style={{ fontFamily: "var(--font-sans)", fontWeight: 900, fontSize: 17, letterSpacing: "-0.03em", color: "var(--text-title)" }}>ouvi</span>
            <p style={{ font: "var(--type-caption)", color: "var(--text-muted)", marginTop: "var(--space-3)" }}>
              Gravador de reuniões e base de conhecimento local para macOS. GPL-3.0. Sem telemetria.
            </p>
          </div>
          <div style={{ display: "flex", gap: "var(--space-9)" }}>
            {[["Produto",["Reuniões","Ditado","Base de conhecimento","MCP"]],["Projeto",["GitHub","Changelog","Licença","Roadmap"]]].map(([t, items]) => (
              <div key={t}>
                <div style={{ font: "var(--type-micro)", textTransform: "uppercase", letterSpacing: "var(--tracking-label)", color: "var(--text-faint)", marginBottom: "var(--space-3)" }}>{t}</div>
                <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
                  {items.map(i => <a key={i} href="#" style={{ font: "var(--type-caption)" }}>{i}</a>)}
                </div>
              </div>
            ))}
          </div>
        </div>
      </footer>
    </div>
  );
}
