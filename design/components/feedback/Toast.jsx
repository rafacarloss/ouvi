import React from "react";
import { Icon } from "../core/Icon.jsx";

const TONES = {
  neutral: { icon: "check", color: "var(--text-muted)" },
  success: { icon: "check", color: "var(--accent)" },
  danger: { icon: "x", color: "var(--danger)" },
  cloud: { icon: "cloud", color: "var(--caution)" },
};

/** Transient confirmation. One sentence, no title, no emoji. */
export function Toast({ tone = "neutral", children, action, onDismiss, style, ...rest }) {
  const t = TONES[tone] || TONES.neutral;
  return (
    <div
      {...rest}
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: "var(--space-3)",
        padding: "8px 10px 8px 12px",
        background: "var(--bg-surface)",
        borderRadius: "var(--radius-lg)",
        boxShadow: "var(--shadow-popover)",
        font: "var(--type-ui)",
        color: "var(--text-body)",
        animation: "ouvi-fade-up var(--dur-base) var(--ease-out)",
        ...style,
      }}
    >
      <Icon name={t.icon} size={15} style={{ color: t.color }} />
      <span>{children}</span>
      {action}
      {onDismiss ? (
        <span onClick={onDismiss} style={{ cursor: "pointer", color: "var(--text-faint)", display: "inline-flex" }}>
          <Icon name="x" size={13} />
        </span>
      ) : null}
    </div>
  );
}
