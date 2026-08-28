export interface TranscriptLineProps extends React.HTMLAttributes<HTMLDivElement> {
  speaker: React.ReactNode;
  slot?: number;
  unnamed?: boolean;
  /** Mono start time. */
  time?: React.ReactNode;
  text?: React.ReactNode;
  /** Pass-1 streaming output: faint until re-transcribed. */
  draft?: boolean;
  /** Currently playing / cited line. */
  active?: boolean;
  onSeek?: () => void;
}
export declare function TranscriptLine(props: TranscriptLineProps): JSX.Element;
