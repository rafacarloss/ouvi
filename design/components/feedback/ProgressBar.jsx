import React from "react";

/** Determinate progress for model downloads and pass-2 re-transcription. */
export function ProgressBar({ value = 0, label, detail, style, ...rest }) {
  return (
    <div {...rest} style={{ display: "flex", flexDirection: "column", gap: "var(--space-2)", ...style }}>
      {label || detail ? (
        <div style={{ display: "flex", justifyContent: "space-between", gap: "var(--space-4)" }}>
          <span style={{ font: "var(--type-caption)", color: "var(--text-body)" }}>{label}</span>
          <span style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)" }}>{detail}</span>
        </div>
      ) : null}
      <div style={{ height: 4, borderRadius: "var(--radius-pill)", background: "var(--paper-3)", overflow: "hidden" }}>
        <div
          style={{
            width: `${Math.max(0, Math.min(100, value))}%`,
            height: "100%",
            background: "var(--accent)",
            borderRadius: "var(--radius-pill)",
            transition: "width var(--dur-base) var(--ease-out)",
          }}
        />
      </div>
    </div>
  );
}
