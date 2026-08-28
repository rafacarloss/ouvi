import React from "react";
import { Icon } from "../core/Icon.jsx";

/** 30px source-list row: sections, folders, people, saved searches. */
export function SidebarItem({ icon, label, count, selected = false, indent = 0, onClick, style, ...rest }) {
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
        gap: "var(--space-3)",
        height: "var(--row-height)",
        padding: `0 var(--space-3) 0 ${8 + indent * 14}px`,
        borderRadius: "var(--radius-sm)",
        cursor: "pointer",
        color: selected ? "var(--text-body)" : "var(--text-muted)",
        background: selected ? "var(--bg-selected)" : hover ? "var(--bg-hover)" : "transparent",
        font: selected ? "var(--type-ui-medium)" : "var(--type-ui)",
        transition: "var(--transition-control)",
        ...style,
      }}
    >
      {icon ? <Icon name={icon} size={15} style={{ color: selected ? "var(--accent)" : "var(--text-faint)" }} /> : null}
      <span style={{ flex: 1, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{label}</span>
      {count != null ? (
        <span style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)" }}>{count}</span>
      ) : null}
    </div>
  );
}
