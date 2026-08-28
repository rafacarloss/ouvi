export interface SessionRowProps extends Omit<React.HTMLAttributes<HTMLDivElement>, "style"> {
  title: React.ReactNode;
  /** Mono relative date, e.g. "hoje 14:00". */
  when?: React.ReactNode;
  /** Mono duration, e.g. "41 min". */
  duration?: React.ReactNode;
  /** Mono speaker count, e.g. "3 falantes". */
  speakers?: React.ReactNode;
  selected?: boolean;
  /** Shows the amber cloud badge. */
  cloud?: boolean;
  /** Shows the pulsing live badge. */
  live?: boolean;
  style?: React.CSSProperties;
}
export declare function SessionRow(props: SessionRowProps): JSX.Element;
