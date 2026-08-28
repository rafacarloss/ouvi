import React from "react";
import { Icon } from "../core/Icon.jsx";

/** States where processing happened. The app's central promise, made visible. */
export function PrivacyBadge({ mode = "local", detail, style, ...rest }) {
  const local = mode === "local";
  return (
    <span
      {...rest}
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: "var(--space-2)",
        padding: "4px 8px",
        borderRadius: "var(--radius-pill)",
        background: local ? "var(--accent-soft)" : "var(--caution-soft)",
        color: local ? "var(--accent-soft-text)" : "var(--caution)",
        font: "var(--type-caption)",
        ...style,
      }}
    >
      <Icon name={local ? "shield-check" : "cloud"} size={13} />
      <span style={{ fontFamily: "var(--font-mono)", fontSize: "var(--text-2xs)", textTransform: "uppercase", letterSpacing: "var(--tracking-label)" }}>
        {local ? "local" : "nuvem"}
      </span>
      {detail ? <span style={{ color: "inherit", opacity: 0.85 }}>{detail}</span> : null}
    </span>
  );
}
