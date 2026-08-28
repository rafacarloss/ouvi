import React from "react";

/** Live amplitude bars. Never animate when idle — a still waveform means no signal. */
export function Waveform({ bars = 24, live = true, height = 22, color = "var(--live)", style, ...rest }) {
  const seeds = React.useMemo(
    () => Array.from({ length: bars }, (_, i) => 0.55 + ((i * 37) % 45) / 100),
    [bars]
  );
  return (
    <div
      {...rest}
      style={{ display: "flex", alignItems: "center", gap: 2, height, ...style }}
    >
      {seeds.map((s, i) => (
        <span
          key={i}
          style={{
            width: 2,
            height: "100%",
            borderRadius: 1,
            background: color,
            opacity: live ? 1 : 0.3,
            transformOrigin: "center",
            transform: live ? undefined : "scaleY(0.18)",
            animation: live ? `ouvi-bar ${(0.5 + s * 0.6).toFixed(2)}s var(--ease-in-out) infinite` : "none",
            animationDelay: live ? `${(i * 0.055).toFixed(2)}s` : undefined,
          }}
        />
      ))}
    </div>
  );
}
