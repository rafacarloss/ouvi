/**
 * @startingPoint section="Dictation" subtitle="Floating dictation HUD in all states" viewport="700x180"
 */
export interface DictationPillProps extends Omit<React.HTMLAttributes<HTMLDivElement>, "style"> {
  state?: "idle" | "listening" | "cleaning" | "inserted" | "blocked";
  /** UI language of the built-in copy. */
  lang?: "pt" | "en";
  /** Mono target-app hint, e.g. "Slack · casual". */
  target?: React.ReactNode;
  style?: React.CSSProperties;
}
export declare function DictationPill(props: DictationPillProps): JSX.Element;
