export interface WaveformProps extends React.HTMLAttributes<HTMLDivElement> {
  bars?: number;
  /** false renders a flat, dimmed line — the honest "no signal" state. */
  live?: boolean;
  height?: number;
  /** Defaults to --live; pass a --speaker-* var in the transcript rail. */
  color?: string;
  children?: never;
}
export declare function Waveform(props: WaveformProps): JSX.Element;
