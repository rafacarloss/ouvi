import React from "react";
import { Icon } from "../core/Icon.jsx";
import { Waveform } from "../meeting/Waveform.jsx";
import { Kbd } from "../core/Kbd.jsx";

const COPY = {
  idle: { pt: "Segure fn para falar", en: "Hold fn to speak" },
  listening: { pt: "Fale.", en: "Speak." },
  cleaning: { pt: "Limpando…", en: "Cleaning up…" },
  inserted: { pt: "Inserido", en: "Inserted" },
  blocked: { pt: "Campo protegido", en: "Secure field" },
};

/** The floating HUD that never takes focus. Vibrant, 220ms in, bottom-centered. */
export function DictationPill({ state = "listening", lang = "pt", target, style, ...rest }) {
  const copy = (COPY[state] || COPY.idle)[lang];
  const listening = state === "listening";
  return (
    <div
      {...rest}
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: "var(--space-4)",
        padding: "8px 14px",
        borderRadius: "var(--radius-pill)",
        background: "var(--hud-tint)",
        backdropFilter: "var(--blur-hud)",
        WebkitBackdropFilter: "var(--blur-hud)",
        boxShadow: "var(--shadow-hud)",
        animation: "ouvi-fade-up var(--dur-hud) var(--ease-out)",
        ...style,
      }}
    >
      {state === "blocked" ? (
        <Icon name="mic-off" size={16} style={{ color: "var(--danger)" }} />
      ) : state === "inserted" ? (
        <Icon name="check" size={16} style={{ color: "var(--accent)" }} />
      ) : (
        <Waveform bars={16} live={listening} height={18} />
      )}
      <span style={{ font: "var(--type-ui-medium)", color: "var(--text-body)" }}>{copy}</span>
      {target ? (
        <span style={{ font: "var(--type-mono-xs)", color: "var(--text-faint)" }}>{target}</span>
      ) : null}
      {state === "idle" ? <Kbd keys={["fn"]} /> : null}
    </div>
  );
}
