import React from "react";

const TONES = {
  neutral: { background: "var(--bg-inset)", color: "var(--text-muted)" },
  local: { background: "var(--accent-soft)", color: "var(--accent-soft-text)" },
  cloud: { background: "var(--caution-soft)", color: "var(--caution)" },
  danger: { background: "var(--danger-soft)", color: "var(--danger)" },
  live: { background: "var(--accent-soft)", color: "var(--accent-soft-text)" },
};

/** Uppercase mono micro-label. Status is never a glyph alone. */
export function Badge({ tone = "neutral", dot = false, children, style, ...rest }) {
  const t = TONES[tone] || TONES.neutral;
  return (
    <span
      {...rest}
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: "var(--space-2)",
        font: "var(--type-micro)",
        fontFamily: "var(--font-mono)",
        textTransform: "uppercase",
        letterSpacing: "var(--tracking-label)",
        padding: "3px 7px",
        borderRadius: "var(--radius-pill)",
        ...t,
        ...style,
      }}
    >
      {dot ? (
        <span
          style={{
            width: 6,
            height: 6,
            borderRadius: "50%",
            background: "var(--live)",
            boxShadow: tone === "live" ? "var(--glow-live)" : "none",
            animation: tone === "live" ? "ouvi-pulse 1.2s var(--ease-in-out) infinite" : "none",
          }}
        />
      ) : null}
      {children}
    </span>
  );
}
