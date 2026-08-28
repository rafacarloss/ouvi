export interface TagProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Lucide icon name, e.g. "user", "building-2", "folder". */
  icon?: string;
  /** When provided, renders a dismiss affordance. */
  onRemove?: () => void;
  children?: React.ReactNode;
}
export declare function Tag(props: TagProps): JSX.Element;
