function DictationHUD() {
  const [state, setState] = React.useState("listening");
  const text = {
    idle: "",
    listening: "",
    cleaning: "então o próximo passo é mandar o escopo até sexta ãã e marcar o comitê",
    inserted: "Próximo passo: mando o escopo até sexta e marcamos o comitê.",
    blocked: "",
  }[state];

  return (
    <div style={{ height: "100%", position: "relative", background: "linear-gradient(160deg,#243430,#131c1a 65%,#0c1211)", display: "flex", alignItems: "center", justifyContent: "center", overflow: "hidden" }}>
      {/* stand-in for the app receiving the text */}
      <div style={{ width: 560, background: "var(--bg-surface)", borderRadius: "var(--radius-lg)", boxShadow: "var(--shadow-sheet)", overflow: "hidden" }}>
        <div style={{ height: 34, borderBottom: "1px solid var(--border-hairline)", display: "flex", alignItems: "center", gap: 8, padding: "0 12px" }}>
          <span style={{ width: 8, height: 8, borderRadius: "50%", background: "var(--paper-4)" }} />
          <span style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)" }}>app em foco · campo de texto</span>
        </div>
        <div style={{ padding: "var(--space-5)", minHeight: 120, font: "var(--type-reading)", color: state === "inserted" ? "var(--text-body)" : "var(--text-faint)" }}>
          {text || "o cursor está aqui"}
          <span style={{ display: "inline-block", width: 1, height: 16, background: "var(--accent)", verticalAlign: "text-bottom", marginLeft: 1 }} />
        </div>
      </div>

      <div style={{ position: "absolute", bottom: 78, left: "50%", transform: "translateX(-50%)" }}>
        <DictationPill state={state} target={state === "blocked" ? undefined : "Slack · casual"} />
      </div>

      <div style={{ position: "absolute", bottom: 20, left: "50%", transform: "translateX(-50%)", display: "flex", gap: 6, background: "var(--bg-surface)", padding: 6, borderRadius: "var(--radius-pill)", boxShadow: "var(--shadow-popover)" }}>
        {["idle","listening","cleaning","inserted","blocked"].map(s => (
          <Button key={s} size="sm" variant={s === state ? "primary" : "ghost"} onClick={() => setState(s)}>{s}</Button>
        ))}
      </div>
    </div>
  );
}
