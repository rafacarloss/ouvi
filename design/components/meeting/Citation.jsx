import React from "react";
import { Icon } from "../core/Icon.jsx";

/** Mono chip that ties an AI sentence to the moment in the recording that produced it. */
export function Citation({ time, onClick, style, ...rest }) {
  const [hover, setHover] = React.useState(false);
  return (
    <span
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      {...rest}
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 3,
        verticalAlign: "baseline",
        marginLeft: 4,
        padding: "1px 5px",
        borderRadius: "var(--radius-xs)",
        font: "var(--type-mono-xs)",
        letterSpacing: "var(--tracking-mono)",
        color: hover ? "var(--accent-soft-text)" : "var(--text-faint)",
        background: hover ? "var(--accent-soft)" : "var(--bg-inset)",
        cursor: "pointer",
        transition: "var(--transition-control)",
        ...style,
      }}
    >
      <Icon name="link" size={9} />
      {time}
    </span>
  );
}
