function MenuBarPanel() {
  return (
    <div style={{ height: "100%", position: "relative", background: "linear-gradient(160deg, #2b3a34, #16211d 60%, #0e1614)", overflow: "hidden" }}>
      {/* fake menu bar */}
      <div style={{ height: 26, background: "rgba(255,255,255,.14)", backdropFilter: "blur(20px)", display: "flex", alignItems: "center", justifyContent: "flex-end", gap: 16, padding: "0 14px", font: "var(--type-caption)", color: "#fff" }}>
        <span style={{ display: "inline-flex", alignItems: "center", gap: 5, fontFamily: "var(--font-sans)", fontWeight: 900, letterSpacing: "-0.03em" }}>
          ouvi <span style={{ width: 5, height: 5, borderRadius: "50%", background: "var(--green-500)" }} />
        </span>
        <span style={{ fontFamily: "var(--font-mono)", fontSize: 11 }}>qua 27 ago 14:12</span>
      </div>

      <div style={{ position: "absolute", top: 34, right: 90, width: 320, borderRadius: "var(--radius-xl)", background: "var(--hud-tint)", backdropFilter: "var(--blur-hud)", WebkitBackdropFilter: "var(--blur-hud)", boxShadow: "var(--shadow-hud)", padding: "var(--space-4)", display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <span style={{ font: "var(--type-ui-medium)" }}>Agora</span>
          <PrivacyBadge mode="local" />
        </div>

        <Card inset padding="sm">
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: "var(--space-3)" }}>
            <div style={{ minWidth: 0 }}>
              <div style={{ font: "var(--type-ui-medium)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>Discovery — Superior Grocers</div>
              <div style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)", marginTop: 2 }}>14:00 – 15:00 · Google Meet</div>
            </div>
            <RecordButton state="idle" size="sm" />
          </div>
        </Card>

        <div>
          <div style={{ font: "var(--type-micro)", textTransform: "uppercase", letterSpacing: "var(--tracking-label)", color: "var(--text-faint)", padding: "0 0 6px 2px" }}>Depois hoje</div>
          <SidebarItem icon="calendar" label="1:1 — Marina" count="16:00" />
          <SidebarItem icon="calendar" label="Giro — retro" count="17:30" />
        </div>

        <div style={{ borderTop: "1px solid var(--border-hairline)", paddingTop: "var(--space-4)", display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <span style={{ font: "var(--type-ui)" }}>Ditado</span>
            <span style={{ display: "flex", alignItems: "center", gap: "var(--space-3)" }}>
              <Kbd keys={["fn"]} />
              <Switch checked onChange={() => {}} />
            </span>
          </div>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <span style={{ font: "var(--type-ui)" }}>Detectar reuniões</span>
            <Switch checked onChange={() => {}} />
          </div>
        </div>

        <div style={{ borderTop: "1px solid var(--border-hairline)", paddingTop: "var(--space-3)", display: "flex", gap: "var(--space-2)" }}>
          <Button variant="ghost" size="sm" icon="folder">Abrir vault</Button>
          <Button variant="ghost" size="sm" icon="settings">Ajustes</Button>
        </div>
      </div>
    </div>
  );
}
