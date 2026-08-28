export interface SelectOption { value: string; label: string }
export interface SelectProps extends Omit<React.SelectHTMLAttributes<HTMLSelectElement>, "style"> {
  options?: (string | SelectOption)[];
  /** Render the value in Space Mono — use for model names, paths, languages codes. */
  mono?: boolean;
  style?: React.CSSProperties;
}
export declare function Select(props: SelectProps): JSX.Element;
