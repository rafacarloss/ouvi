import React from "react";

const PAD = { sm: "var(--space-4)", md: "var(--space-5)", lg: "var(--space-7)" };

/** Hairline-ringed surface. No left-border accent stripes, ever. */
export function Card({ padding = "md", elevation = "card", inset = false, children, style, ...rest }) {
  return (
    <div
      {...rest}
      style={{
        background: inset ? "var(--bg-inset)" : "var(--bg-surface)",
        borderRadius: "var(--radius-card)",
        padding: PAD[padding] || PAD.md,
        boxShadow: inset ? "inset 0 0 0 0.5px var(--border-hairline)" : `var(--shadow-${elevation})`,
        ...style,
      }}
    >
      {children}
    </div>
  );
}
