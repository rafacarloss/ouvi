export interface TabsProps extends Omit<React.HTMLAttributes<HTMLDivElement>, "onChange" | "style"> {
  tabs?: (string | { value: string; label: string })[];
  value?: string;
  onChange?: (value: string) => void;
  style?: React.CSSProperties;
}
export declare function Tabs(props: TabsProps): JSX.Element;
