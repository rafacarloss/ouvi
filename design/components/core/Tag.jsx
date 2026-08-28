import React from "react";
import { Icon } from "./Icon.jsx";

/** Sentence-case metadata chip: people, companies, projects, templates. */
export function Tag({ icon, onRemove, children, style, ...rest }) {
  return (
    <span
      {...rest}
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: "var(--space-2)",
        font: "var(--type-caption)",
        color: "var(--text-muted)",
        background: "var(--bg-inset)",
        padding: "3px 8px",
        borderRadius: "var(--radius-sm)",
        boxShadow: "inset 0 0 0 0.5px var(--border-hairline)",
        ...style,
      }}
    >
      {icon ? <Icon name={icon} size={12} /> : null}
      {children}
      {onRemove ? (
        <span onClick={onRemove} style={{ cursor: "pointer", display: "inline-flex", opacity: 0.7 }}>
          <Icon name="x" size={11} />
        </span>
      ) : null}
    </span>
  );
}
