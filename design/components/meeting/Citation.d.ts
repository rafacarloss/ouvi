export interface CitationProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Timecode of the source utterance, e.g. "14:22". */
  time: React.ReactNode;
}
export declare function Citation(props: CitationProps): JSX.Element;
