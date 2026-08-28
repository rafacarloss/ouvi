export interface SpeakerChipProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** "Você" / "You" for the mic channel; a real name once enrolled. */
  name: React.ReactNode;
  /** 0 = me (green), 1–4 = the fixed speaker color slots. */
  slot?: number;
  /** Renders the inline "dar nome" affordance. */
  unnamed?: boolean;
  onName?: () => void;
}
export declare function SpeakerChip(props: SpeakerChipProps): JSX.Element;
