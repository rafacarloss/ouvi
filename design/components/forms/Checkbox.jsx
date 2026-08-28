import React from "react";
import { Icon } from "../core/Icon.jsx";

/** Checkbox with label; description sits under the label in caption size. */
export function Checkbox({ checked = false, onChange, label, description, disabled = false, style, ...rest }) {
  return (
    <label
      {...rest}
      style={{
        display: "flex",
        gap: "var(--space-3)",
        alignItems: "flex-start",
        cursor: disabled ? "default" : "pointer",
        opacity: disabled ? 0.4 : 1,
        ...style,
      }}
    >
      <span
        onClick={() => !disabled && onChange && onChange(!checked)}
        style={{
          width: 15,
          height: 15,
          marginTop: 1,
          flex: "0 0 auto",
          display: "inline-flex",
          alignItems: "center",
          justifyContent: "center",
          borderRadius: "var(--radius-xs)",
          background: checked ? "var(--accent)" : "var(--bg-inset)",
          color: "var(--text-on-accent)",
          boxShadow: checked ? "none" : "inset 0 0 0 0.5px var(--border-strong)",
          transition: "var(--transition-control)",
        }}
      >
        {checked ? <Icon name="check" size={11} /> : null}
      </span>
      <span>
        <span style={{ font: "var(--type-ui)", color: "var(--text-body)", display: "block" }}>{label}</span>
        {description ? (
          <span style={{ font: "var(--type-caption)", color: "var(--text-muted)", display: "block", marginTop: 2 }}>
            {description}
          </span>
        ) : null}
      </span>
    </label>
  );
}
