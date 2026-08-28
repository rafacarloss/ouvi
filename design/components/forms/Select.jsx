import React from "react";
import { Icon } from "../core/Icon.jsx";

/** Native popup-button look: label + chevron, mono values for model names. */
export function Select({ options = [], value, onChange, mono = false, disabled = false, style, ...rest }) {
  return (
    <div style={{ position: "relative", display: "inline-flex", alignItems: "center", ...style }}>
      <select
        value={value}
        onChange={onChange}
        disabled={disabled}
        {...rest}
        style={{
          appearance: "none",
          height: "var(--control-height)",
          padding: "0 26px 0 8px",
          font: mono ? "var(--type-mono)" : "var(--type-ui)",
          color: "var(--text-body)",
          background: "var(--bg-surface)",
          border: "none",
          borderRadius: "var(--radius-control)",
          boxShadow: "var(--shadow-control)",
          opacity: disabled ? 0.4 : 1,
          cursor: disabled ? "default" : "pointer",
        }}
      >
        {options.map((o) => {
          const v = typeof o === "string" ? o : o.value;
          const l = typeof o === "string" ? o : o.label;
          return <option key={v} value={v}>{l}</option>;
        })}
      </select>
      <Icon
        name="chevron-down"
        size={13}
        style={{ position: "absolute", right: 7, color: "var(--text-faint)", pointerEvents: "none" }}
      />
    </div>
  );
}
