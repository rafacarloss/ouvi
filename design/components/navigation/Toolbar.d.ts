export interface ToolbarProps extends React.HTMLAttributes<HTMLDivElement> {
  leading?: React.ReactNode;
  trailing?: React.ReactNode;
  /** Translucent + blurred; only for surfaces that float over other apps. */
  vibrant?: boolean;
  children?: React.ReactNode;
}
export declare function Toolbar(props: ToolbarProps): JSX.Element;
