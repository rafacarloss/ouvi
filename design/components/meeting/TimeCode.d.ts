export interface TimeCodeProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Formatted time, e.g. "00:14:22" or "14:22". */
  children?: React.ReactNode;
  /** Provide to make it seek the recording; turns green on hover. */
  onSeek?: () => void;
}
export declare function TimeCode(props: TimeCodeProps): JSX.Element;
