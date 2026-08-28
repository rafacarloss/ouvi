export interface InputProps extends Omit<React.InputHTMLAttributes<HTMLInputElement>, "size" | "style"> {
  size?: "sm" | "md" | "lg";
  /** Red inset ring; pair with a one-sentence error below. */
  invalid?: boolean;
  style?: React.CSSProperties;
}
export declare function Input(props: InputProps): JSX.Element;
