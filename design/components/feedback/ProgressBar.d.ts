export interface ProgressBarProps extends React.HTMLAttributes<HTMLDivElement> {
  /** 0–100. */
  value?: number;
  label?: React.ReactNode;
  /** Mono right-aligned detail, e.g. "612 MB / 1,2 GB". */
  detail?: React.ReactNode;
}
export declare function ProgressBar(props: ProgressBarProps): JSX.Element;
