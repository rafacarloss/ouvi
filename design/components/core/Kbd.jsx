import React from "react";

/** Keycap. Modifiers as unicode: ⌘ ⇧ ⌥ ⌃ ⏎ ␣ fn */
export function Kbd({ keys = [], children, style, ...rest }) {
  const list = keys.length ? keys : String(children || "").split("");
  return (
    <span {...rest} style={{ display: "inline-flex", gap: "var(--space-1)", ...style }}>
      {list.map((k, i) => (
        <kbd
          key={i}
          style={{
            font: "var(--type-mono-xs)",
            fontFamily: "var(--font-keycap)",
            letterSpacing: "var(--tracking-mono)",
            color: "var(--text-muted)",
            background: "var(--bg-inset)",
            padding: "2px 6px",
            minWidth: 18,
            textAlign: "center",
            borderRadius: "var(--radius-xs)",
            boxShadow: "inset 0 0 0 0.5px var(--border-strong)",
          }}
        >
          {k}
        </kbd>
      ))}
    </span>
  );
}
