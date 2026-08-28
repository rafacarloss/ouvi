import React from "react";
import { Icon } from "./Icon.jsx";

/** Square, label-less control for toolbars and rows. Always give a title. */
export function IconButton({ icon, title, size = 28, active = false, disabled = false, style, ...rest }) {
  const [hover, setHover] = React.useState(false);
  const [press, setPress] = React.useState(false);
  return (
    <button
      type="button"
      title={title}
      aria-label={title}
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
        width: size,
        height: size,
        border: "none",
        borderRadius: "var(--radius-sm)",
        background: press ? "var(--bg-active)" : active ? "var(--bg-active)" : hover && !disabled ? "var(--bg-hover)" : "transparent",
        color: active ? "var(--accent)" : "var(--text-muted)",
        opacity: disabled ? 0.4 : 1,
        cursor: disabled ? "default" : "pointer",
        transition: "var(--transition-control)",
        ...style,
      }}
    >
      <Icon name={icon} size={Math.round(size * 0.57)} />
    </button>
  );
}
