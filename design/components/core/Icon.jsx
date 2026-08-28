import React from "react";

const CDN = "https://cdn.jsdelivr.net/npm/lucide-static@latest/icons";

/** Lucide glyph painted with currentColor via CSS mask. */
export function Icon({ name, size = 16, base = CDN, style, ...rest }) {
  const url = `url("${base}/${name}.svg")`;
  return (
    <span
      aria-hidden="true"
      {...rest}
      style={{
        display: "inline-block",
        width: size,
        height: size,
        flex: "0 0 auto",
        background: "currentColor",
        WebkitMaskImage: url,
        maskImage: url,
        WebkitMaskRepeat: "no-repeat",
        maskRepeat: "no-repeat",
        WebkitMaskSize: "contain",
        maskSize: "contain",
        WebkitMaskPosition: "center",
        maskPosition: "center",
        ...style,
      }}
    />
  );
}
