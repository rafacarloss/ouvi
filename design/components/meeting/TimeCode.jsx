import React from "react";

/** Mono timestamp; clickable when it seeks the audio. */
export function TimeCode({ children, onSeek, style, ...rest }) {
  const [hover, setHover] = React.useState(false);
  const clickable = Boolean(onSeek);
  return (
    <span
      onClick={onSeek}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      {...rest}
      style={{
        font: "var(--type-mono-xs)",
        letterSpacing: "var(--tracking-mono)",
        color: clickable && hover ? "var(--accent)" : "var(--text-faint)",
        cursor: clickable ? "pointer" : "default",
        fontVariantNumeric: "tabular-nums",
        ...style,
      }}
    >
      {children}
    </span>
  );
}
