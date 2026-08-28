import React from "react";

/** Two-to-four mutually exclusive views. Also the theme and language picker. */
export function SegmentedControl({ options = [], value, onChange, size = "md", style, ...rest }) {
  const h = size === "sm" ? "var(--control-height-sm)" : "var(--control-height)";
  return (
    <div
      {...rest}
      style={{
        display: "inline-flex",
        padding: 2,
        gap: 2,
        height: h,
        background: "var(--bg-inset)",
        borderRadius: "var(--radius-md)",
        boxShadow: "inset 0 0 0 0.5px var(--border-hairline)",
        ...style,
      }}
    >
      {options.map((o) => {
        const v = typeof o === "string" ? o : o.value;
        const l = typeof o === "string" ? o : o.label;
        const on = v === value;
        return (
          <button
            key={v}
            type="button"
            onClick={() => onChange && onChange(v)}
            style={{
              border: "none",
              padding: "0 10px",
              borderRadius: "var(--radius-sm)",
              font: on ? "var(--type-ui-medium)" : "var(--type-ui)",
              color: on ? "var(--text-body)" : "var(--text-muted)",
              background: on ? "var(--bg-surface)" : "transparent",
              boxShadow: on ? "var(--shadow-control)" : "none",
              cursor: "pointer",
              transition: "var(--transition-control)",
            }}
          >
            {l}
          </button>
        );
      })}
    </div>
  );
}
