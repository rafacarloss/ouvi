import React from "react";
import { Icon } from "../core/Icon.jsx";

/** The single most important control in Ouvi. Three states: idle, armed, recording. */
export function RecordButton({ state = "idle", elapsed, onClick, size = "lg", style, ...rest }) {
  const [hover, setHover] = React.useState(false);
  const recording = state === "recording";
  const armed = state === "armed";
  const h = size === "sm" ? "var(--control-height)" : "var(--control-height-lg)";
  return (
    <button
      type="button"
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      {...rest}
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: "var(--space-3)",
        height: h,
        padding: size === "sm" ? "0 10px" : "0 14px",
        border: "none",
        borderRadius: "var(--radius-pill)",
        cursor: "pointer",
        font: "var(--type-ui-medium)",
        background: recording ? "var(--accent-soft)" : hover ? "var(--accent-hover)" : "var(--accent)",
        color: recording ? "var(--accent-soft-text)" : "var(--text-on-accent)",
        boxShadow: recording ? "var(--glow-live)" : "var(--shadow-control)",
        transition: "var(--transition-control)",
        ...style,
      }}
    >
      {recording ? (
        <>
          <span
            style={{
              width: 8,
              height: 8,
              borderRadius: "50%",
              background: "var(--live)",
              animation: "ouvi-pulse 1.2s var(--ease-in-out) infinite",
            }}
          />
          <span style={{ font: "var(--type-mono)", letterSpacing: "var(--tracking-mono)" }}>{elapsed}</span>
          <Icon name="square" size={13} />
        </>
      ) : (
        <>
          <Icon name={armed ? "mic" : "circle"} size={14} />
          {armed ? "Armado" : "Gravar"}
        </>
      )}
    </button>
  );
}
