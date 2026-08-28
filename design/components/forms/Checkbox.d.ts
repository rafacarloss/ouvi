export interface CheckboxProps extends Omit<React.HTMLAttributes<HTMLLabelElement>, "onChange" | "style"> {
  checked?: boolean;
  onChange?: (next: boolean) => void;
  label?: React.ReactNode;
  /** Max two lines of help text. */
  description?: React.ReactNode;
  disabled?: boolean;
  style?: React.CSSProperties;
}
export declare function Checkbox(props: CheckboxProps): JSX.Element;
