export interface SearchFieldProps extends Omit<React.HTMLAttributes<HTMLDivElement>, "onChange" | "style"> {
  placeholder?: string;
  /** Keycaps rendered at the trailing edge, e.g. ["⌘","K"]. */
  shortcut?: string[];
  value?: string;
  onChange?: React.ChangeEventHandler<HTMLInputElement>;
  style?: React.CSSProperties;
}
export declare function SearchField(props: SearchFieldProps): JSX.Element;
