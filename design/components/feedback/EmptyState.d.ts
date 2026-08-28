export interface EmptyStateProps extends React.HTMLAttributes<HTMLDivElement> {
  icon?: string;
  /** Exactly one sentence. */
  title: React.ReactNode;
  /** One button, usually primary. */
  action?: React.ReactNode;
}
export declare function EmptyState(props: EmptyStateProps): JSX.Element;
