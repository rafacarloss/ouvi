import React from "react";

/** macOS-style toggle for immediate, reversible settings. */
export function Switch({ checked = false, onChange, disabled = false, label, style, ...rest }) {
  const track = checked ? "var(--accent)" : "var(--paper-4)";
  return (
    <label
      {...rest}
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: "var(--space-3)",
        cursor: disabled ? "default" : "pointer",
        opacity: disabled ? 0.4 : 1,
        ...style,
      }}
    >
      <span
        onClick={() => !disabled && onChange && onChange(!checked)}
        style={{
          width: 34,
          height: 20,
          borderRadius: "var(--radius-pill)",
          background: track,
          padding: 2,
          display: "inline-flex",
          transition: "background-color var(--dur-fast) var(--ease-out)",
          boxShadow: "inset 0 0 0 0.5px var(--border-hairline)",
        }}
      >
        <span
          style={{
            width: 16,
            height: 16,
            borderRadius: "50%",
            background: "#fff",
            boxShadow: "0 1px 2px rgba(0,0,0,.25)",
            transform: checked ? "translateX(14px)" : "none",
            transition: "transform var(--dur-fast) var(--ease-snap)",
          }}
        />
      </span>
      {label ? <span style={{ font: "var(--type-ui)", color: "var(--text-body)" }}>{label}</span> : null}
    </label>
  );
}
