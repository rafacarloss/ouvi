export interface KbdProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** One cap per entry, e.g. ["⌘","⇧","O"]. */
  keys?: string[];
  children?: React.ReactNode;
}
export declare function Kbd(props: KbdProps): JSX.Element;
