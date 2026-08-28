import React from "react";
import { SpeakerChip } from "./SpeakerChip.jsx";
import { TimeCode } from "./TimeCode.jsx";

/** One diarized utterance. Draft text stays faint until pass 2 lands. */
export function TranscriptLine({ speaker, slot = 0, unnamed = false, time, text, draft = false, active = false, onSeek, style, ...rest }) {
  const [hover, setHover] = React.useState(false);
  return (
    <div
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      {...rest}
      style={{
        display: "flex",
        flexDirection: "column",
        gap: "var(--space-1)",
        padding: "var(--space-3)",
        borderRadius: "var(--radius-sm)",
        background: active ? "var(--bg-selected)" : hover ? "var(--bg-hover)" : "transparent",
        transition: "background-color var(--dur-fast) var(--ease-out)",
        ...style,
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)" }}>
        <SpeakerChip name={speaker} slot={slot} unnamed={unnamed} />
        <TimeCode onSeek={onSeek}>{time}</TimeCode>
      </div>
      <p
        style={{
          font: "var(--type-reading)",
          color: draft ? "var(--text-draft)" : "var(--text-body)",
          maxWidth: "var(--reading-measure)",
        }}
      >
        {text}
      </p>
    </div>
  );
}
