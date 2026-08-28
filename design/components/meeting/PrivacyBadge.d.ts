export interface PrivacyBadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  mode?: "local" | "cloud";
  /** Factual detail of what happened, e.g. "só o texto do transcript foi enviado". */
  detail?: React.ReactNode;
}
export declare function PrivacyBadge(props: PrivacyBadgeProps): JSX.Element;
