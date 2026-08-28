import React from "react";

/** 44px window toolbar: leading title block, flexible middle, trailing controls. */
export function Toolbar({ leading, trailing, children, vibrant = false, style, ...rest }) {
  return (
    <div
      {...rest}
      style={{
        display: "flex",
        alignItems: "center",
        gap: "var(--space-4)",
        height: "var(--toolbar-height)",
        padding: "0 var(--space-4)",
        borderBottom: "1px solid var(--border-hairline)",
        background: vibrant ? "var(--vibrancy-tint)" : "var(--bg-surface)",
        backdropFilter: vibrant ? "var(--blur-vibrancy)" : undefined,
        ...style,
      }}
    >
      {leading}
      <div style={{ flex: 1, minWidth: 0, display: "flex", alignItems: "center", gap: "var(--space-3)" }}>
        {children}
      </div>
      {trailing}
    </div>
  );
}
