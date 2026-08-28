function Placeholder({ label, height = 320, style }) {
  return (
    <div
      style={{
        height,
        borderRadius: "var(--radius-lg)",
        background: "repeating-linear-gradient(135deg, var(--bg-inset) 0 10px, var(--bg-window) 10px 20px)",
        boxShadow: "inset 0 0 0 0.5px var(--border-strong)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        ...style,
      }}
    >
      <span style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)", letterSpacing: "var(--tracking-mono)", background: "var(--bg-surface)", padding: "4px 8px", borderRadius: "var(--radius-xs)" }}>
        {label}
      </span>
    </div>
  );
}
