export interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** local = ran on this Mac. cloud = text left the device. live = recording now. */
  tone?: "neutral" | "local" | "cloud" | "danger" | "live";
  /** Leading status dot; pulses when tone is "live". */
  dot?: boolean;
  children?: React.ReactNode;
}
export declare function Badge(props: BadgeProps): JSX.Element;
