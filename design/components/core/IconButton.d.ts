export interface IconButtonProps extends Omit<React.ButtonHTMLAttributes<HTMLButtonElement>, "style"> {
  /** Lucide icon name. */
  icon: string;
  /** Required: becomes both title and aria-label. */
  title: string;
  /** Box size in px; 28 in toolbars, 22 inside rows. */
  size?: number;
  /** Toggled-on state — tints the glyph green. */
  active?: boolean;
  disabled?: boolean;
  style?: React.CSSProperties;
}
export declare function IconButton(props: IconButtonProps): JSX.Element;
