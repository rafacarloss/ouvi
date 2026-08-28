export interface SwitchProps extends Omit<React.HTMLAttributes<HTMLLabelElement>, "onChange" | "style"> {
  checked?: boolean;
  onChange?: (next: boolean) => void;
  disabled?: boolean;
  label?: React.ReactNode;
  style?: React.CSSProperties;
}
export declare function Switch(props: SwitchProps): JSX.Element;
