import React from "react";
import { Icon } from "../core/Icon.jsx";
import { Kbd } from "../core/Kbd.jsx";

/** Toolbar search with optional shortcut hint. */
export function SearchField({ placeholder = "Buscar", shortcut, value, onChange, style, ...rest }) {
  const [focus, setFocus] = React.useState(false);
  return (
    <div
      {...rest}
      style={{
        display: "flex",
        alignItems: "center",
        gap: "var(--space-2)",
        height: "var(--control-height)",
        padding: "0 8px",
        background: "var(--bg-inset)",
        borderRadius: "var(--radius-control)",
        boxShadow: focus
          ? "inset 0 0 0 1px var(--border-focus), var(--focus-ring)"
          : "inset 0 0 0 0.5px var(--border-strong)",
        transition: "var(--transition-control)",
        ...style,
      }}
    >
      <Icon name="search" size={14} style={{ color: "var(--text-faint)" }} />
      <input
        value={value}
        onChange={onChange}
        placeholder={placeholder}
        onFocus={() => setFocus(true)}
        onBlur={() => setFocus(false)}
        style={{
          flex: 1,
          minWidth: 0,
          border: "none",
          outline: "none",
          background: "transparent",
          font: "var(--type-ui)",
          color: "var(--text-body)",
        }}
      />
      {shortcut ? <Kbd keys={shortcut} /> : null}
    </div>
  );
}
