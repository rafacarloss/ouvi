export interface SegmentedControlProps extends Omit<React.HTMLAttributes<HTMLDivElement>, "onChange" | "style"> {
  options?: (string | { value: string; label: string })[];
  value?: string;
  onChange?: (value: string) => void;
  size?: "sm" | "md";
  style?: React.CSSProperties;
}
export declare function SegmentedControl(props: SegmentedControlProps): JSX.Element;
