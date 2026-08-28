export interface SidebarItemProps extends Omit<React.HTMLAttributes<HTMLDivElement>, "style"> {
  icon?: string;
  label: React.ReactNode;
  /** Mono trailing count. */
  count?: number | string;
  selected?: boolean;
  /** Nesting level; each step adds 14px of leading inset. */
  indent?: number;
  style?: React.CSSProperties;
}
export declare function SidebarItem(props: SidebarItemProps): JSX.Element;
