import React from "react";
import { Icon } from "../core/Icon.jsx";
import { Badge } from "../core/Badge.jsx";

/** 56px meeting row for the sessions list. */
export function SessionRow({ title, when, duration, speakers, selected = false, cloud = false, live = false, onClick, style, ...rest }) {
  const [hover, setHover] = React.useState(false);
  return (
    <div
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      {...rest}
      style={{
        display: "flex",
        alignItems: "center",
        gap: "var(--space-4)",
        height: "var(--row-height-lg)",
        padding: "0 var(--space-4)",
        borderRadius: "var(--radius-md)",
        cursor: "pointer",
        background: selected ? "var(--bg-selected)" : hover ? "var(--bg-hover)" : "transparent",
        transition: "background-color var(--dur-fast) var(--ease-out)",
        ...style,
      }}
    >
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)" }}>
          <span
            style={{
              font: "var(--type-ui-medium)",
              color: "var(--text-body)",
              overflow: "hidden",
              textOverflow: "ellipsis",
              whiteSpace: "nowrap",
            }}
          >
            {title}
          </span>
          {live ? <Badge tone="live" dot>ao vivo</Badge> : null}
          {cloud ? <Badge tone="cloud">nuvem</Badge> : null}
        </div>
        <div style={{ display: "flex", gap: "var(--space-3)", marginTop: 2, font: "var(--type-mono-xs)", color: "var(--text-faint)" }}>
          <span>{when}</span>
          {duration ? <span>· {duration}</span> : null}
          {speakers ? <span>· {speakers}</span> : null}
        </div>
      </div>
      <Icon name="chevron-right" size={14} style={{ color: "var(--text-faint)", opacity: hover ? 1 : 0.5 }} />
    </div>
  );
}
