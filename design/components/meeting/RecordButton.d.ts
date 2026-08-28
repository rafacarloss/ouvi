/**
 * @startingPoint section="Meeting" subtitle="Record control, waveform, transcript line, citations" viewport="700x260"
 */
export interface RecordButtonProps extends Omit<React.ButtonHTMLAttributes<HTMLButtonElement>, "style"> {
  /** idle = "Gravar"; armed = waiting for the meeting to start; recording = timer + stop. */
  state?: "idle" | "armed" | "recording";
  /** Mono elapsed time, shown only while recording, e.g. "12:04". */
  elapsed?: string;
  size?: "sm" | "lg";
  style?: React.CSSProperties;
}
export declare function RecordButton(props: RecordButtonProps): JSX.Element;
