import React from "react";
import { Icon } from "../core/Icon.jsx";

/** One glyph, one sentence, one action. Never more. */
export function EmptyState({ icon = "audio-lines", title, action, style, ...rest }) {
  return (
    <div
      {...rest}
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: "var(--space-4)",
        padding: "var(--space-9) var(--space-6)",
        textAlign: "center",
        ...style,
      }}
    >
      <Icon name={icon} size={20} style={{ color: "var(--text-faint)" }} />
      <span style={{ font: "var(--type-ui)", color: "var(--text-muted)", maxWidth: "42ch" }}>{title}</span>
      {action}
    </div>
  );
}
