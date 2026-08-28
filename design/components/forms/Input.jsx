import React from "react";

/** Inset single-line field. Green focus ring, hairline at rest. */
export function Input({ size = "md", invalid = false, disabled = false, style, ...rest }) {
  const [focus, setFocus] = React.useState(false);
  const h = size === "sm" ? "var(--control-height-sm)" : size === "lg" ? "var(--control-height-lg)" : "var(--control-height)";
  return (
    <input
      disabled={disabled}
      onFocus={(e) => { setFocus(true); rest.onFocus && rest.onFocus(e); }}
      onBlur={(e) => { setFocus(false); rest.onBlur && rest.onBlur(e); }}
      {...rest}
      style={{
        height: h,
        width: "100%",
        padding: "0 8px",
        font: "var(--type-ui)",
        color: "var(--text-body)",
        background: "var(--bg-inset)",
        border: "none",
        borderRadius: "var(--radius-control)",
        boxShadow: invalid
          ? "inset 0 0 0 1px var(--danger)"
          : focus
          ? "inset 0 0 0 1px var(--border-focus), var(--focus-ring)"
          : "inset 0 0 0 0.5px var(--border-strong), var(--shadow-inset-field)",
        outline: "none",
        opacity: disabled ? 0.4 : 1,
        transition: "var(--transition-control)",
        ...style,
      }}
    />
  );
}
