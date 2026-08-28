import React from "react";
import { Icon } from "./Icon.jsx";

const SIZES = {
  sm: { height: "var(--control-height-sm)", padding: "0 8px", font: "var(--type-caption)", icon: 13 },
  md: { height: "var(--control-height)", padding: "0 12px", font: "var(--type-ui-medium)", icon: 16 },
  lg: { height: "var(--control-height-lg)", padding: "0 16px", font: "var(--type-ui-medium)", icon: 16 },
};

function paint(variant, hover, press) {
  switch (variant) {
    case "primary":
      return {
        background: press ? "var(--accent-press)" : hover ? "var(--accent-hover)" : "var(--accent)",
        color: "var(--text-on-accent)",
        boxShadow: "var(--shadow-control)",
      };
    case "danger":
      return {
        background: press || hover ? "var(--red-600)" : "var(--danger)",
        color: "#fff",
        boxShadow: "var(--shadow-control)",
      };
    case "ghost":
      return {
        background: press ? "var(--bg-active)" : hover ? "var(--bg-hover)" : "transparent",
        color: "var(--text-body)",
        boxShadow: "none",
      };
    default: // secondary
      return {
        background: press ? "var(--bg-active)" : hover ? "var(--bg-hover)" : "var(--bg-surface)",
        color: "var(--text-body)",
        boxShadow: "var(--shadow-control)",
      };
  }
}

/** Standard Ouvi button. Sentence case labels, 1–3 words. */
export function Button({
  variant = "secondary",
  size = "md",
  icon,
  iconRight,
  fullWidth = false,
  disabled = false,
  children,
  style,
  ...rest
}) {
  const [hover, setHover] = React.useState(false);
  const [press, setPress] = React.useState(false);
  const s = SIZES[size] || SIZES.md;
  const filled = variant === "primary" || variant === "danger";

  return (
    <button
      type="button"
      disabled={disabled}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => { setHover(false); setPress(false); }}
      onMouseDown={() => setPress(true)}
      onMouseUp={() => setPress(false)}
      {...rest}
      style={{
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        gap: "var(--space-2)",
        width: fullWidth ? "100%" : undefined,
        flex: "0 0 auto",
        height: s.height,
        padding: s.padding,
        whiteSpace: "nowrap",
        font: s.font,
        letterSpacing: "var(--tracking-ui)",
        borderRadius: "var(--radius-control)",
        border: "none",
        cursor: disabled ? "default" : "pointer",
        opacity: disabled ? 0.4 : 1,
        transform: press && filled && !disabled ? "scale(0.985)" : "none",
        transition: "var(--transition-control), transform var(--dur-instant) var(--ease-out)",
        ...paint(variant, hover && !disabled, press && !disabled),
        ...style,
      }}
    >
      {icon ? <Icon name={icon} size={s.icon} /> : null}
      {children}
      {iconRight ? <Icon name={iconRight} size={s.icon} /> : null}
    </button>
  );
}
