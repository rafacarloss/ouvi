import React from "react";

/** Underlined tabs for in-panel sections (session: Notas / Transcript / Resumo). */
export function Tabs({ tabs = [], value, onChange, style, ...rest }) {
  return (
    <div
      {...rest}
      style={{
        display: "flex",
        gap: "var(--space-5)",
        borderBottom: "1px solid var(--border-hairline)",
        ...style,
      }}
    >
      {tabs.map((t) => {
        const v = typeof t === "string" ? t : t.value;
        const l = typeof t === "string" ? t : t.label;
        const on = v === value;
        return (
          <button
            key={v}
            type="button"
            onClick={() => onChange && onChange(v)}
            style={{
              border: "none",
              background: "transparent",
              padding: "0 0 8px",
              cursor: "pointer",
              font: on ? "var(--type-ui-medium)" : "var(--type-ui)",
              color: on ? "var(--text-body)" : "var(--text-muted)",
              boxShadow: on ? "inset 0 -2px 0 var(--accent)" : "none",
              transition: "var(--transition-control)",
            }}
          >
            {l}
          </button>
        );
      })}
    </div>
  );
}
