import React from "react";

/** Hover explanation on a delay. Sentence case, no period. */
export function Tooltip({ label, side = "top", children, style, ...rest }) {
  const [on, setOn] = React.useState(false);
  const pos =
    side === "bottom"
      ? { top: "calc(100% + 6px)", left: "50%", transform: "translateX(-50%)" }
      : side === "left"
      ? { right: "calc(100% + 6px)", top: "50%", transform: "translateY(-50%)" }
      : side === "right"
      ? { left: "calc(100% + 6px)", top: "50%", transform: "translateY(-50%)" }
      : { bottom: "calc(100% + 6px)", left: "50%", transform: "translateX(-50%)" };
  return (
    <span
      onMouseEnter={() => setOn(true)}
      onMouseLeave={() => setOn(false)}
      {...rest}
      style={{ position: "relative", display: "inline-flex", ...style }}
    >
      {children}
      {on ? (
        <span
          role="tooltip"
          style={{
            position: "absolute",
            ...pos,
            whiteSpace: "nowrap",
            padding: "4px 7px",
            borderRadius: "var(--radius-sm)",
            background: "var(--ink-1)",
            color: "var(--paper-1)",
            font: "var(--type-caption)",
            boxShadow: "var(--shadow-popover)",
            pointerEvents: "none",
            zIndex: 40,
          }}
        >
          {label}
        </span>
      ) : null}
    </span>
  );
}
