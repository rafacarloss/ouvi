export interface IconProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Lucide icon name, kebab-case (e.g. "mic", "shield-check"). */
  name: string;
  /** 16 in chrome, 20 in HUD and empty states. */
  size?: number;
  /** Override the icon source folder (vendor into assets/icons for offline use). */
  base?: string;
}
export declare function Icon(props: IconProps): JSX.Element;
