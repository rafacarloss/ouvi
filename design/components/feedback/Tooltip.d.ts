export interface TooltipProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Sentence case, no trailing period, max ~6 words. */
  label: React.ReactNode;
  side?: "top" | "bottom" | "left" | "right";
  children?: React.ReactNode;
}
export declare function Tooltip(props: TooltipProps): JSX.Element;
