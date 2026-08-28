import React from "react";
import { Icon } from "../core/Icon.jsx";

const SLOTS = ["var(--speaker-me)", "var(--speaker-a)", "var(--speaker-b)", "var(--speaker-c)", "var(--speaker-d)"];

/** Speaker identity. Unnamed speakers invite naming instead of hiding it. */
export function SpeakerChip({ name, slot = 0, unnamed = false, onName, style, ...rest }) {
  const color = SLOTS[slot % SLOTS.length];
  return (
    <span
      onClick={unnamed ? onName : undefined}
      {...rest}
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: "var(--space-2)",
        font: "var(--type-ui-medium)",
        color: unnamed ? "var(--text-faint)" : "var(--text-body)",
        cursor: unnamed ? "pointer" : "default",
        ...style,
      }}
    >
      <span style={{ width: 3, height: 12, borderRadius: 2, background: color }} />
      {name}
      {unnamed ? (
        <span style={{ display: "inline-flex", alignItems: "center", gap: 3, font: "var(--type-caption)", color: "var(--text-link)" }}>
          <Icon name="user" size={11} /> dar nome
        </span>
      ) : null}
    </span>
  );
}
