export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  padding?: "sm" | "md" | "lg";
  /** Maps to --shadow-*; ignored when inset. */
  elevation?: "card" | "raised" | "popover";
  /** Recessed variant on --bg-inset with a hairline ring and no drop shadow. */
  inset?: boolean;
  children?: React.ReactNode;
}
export declare function Card(props: CardProps): JSX.Element;
