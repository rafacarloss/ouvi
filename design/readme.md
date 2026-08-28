# Ouvi Design System

**Ouvi** is a local-first macOS app being built by Rafa: a personal meeting recorder + transcriber
("um Granola pessoal") that doubles as a searchable knowledge base, plus a global dictation mode
("como o Wispr Flow"). Every byte stays on the user's Mac: audio is captured without a meeting bot,
transcribed on-device (Parakeet/FluidAudio on the Neural Engine), diarized locally, and written to a
Markdown vault the user owns. Cloud LLMs (Claude API, BYO key) are opt-in per meeting, text-only, and
always visibly badged. Open source, GPL-3.0, no account, no telemetry.

Tagline in use: **"Your meetings, your voice, your files."**

This design system is the visual and verbal contract for everything Ouvi ships: the desktop app, the
dictation HUD, the onboarding, the open-source landing page and the docs.

## Sources this system was built from

- The product plan pasted into the project by the user (2026-08-27): full feature spec, architecture
  (Swift/SwiftUI, macOS 14.4+, FluidAudio + WhisperKit + MLX, GRDB/FTS5/sqlite-vec, MCP server),
  7-phase roadmap and market research digests (Granola, Wispr Flow, ASR SOTA, OSS competitors, macOS stack).
- The user's answers to the design brief (2026-08-27): dark + light with equal weight; "pure native"
  macOS feel; grotesk-with-character + mono typography; signal green `#2E9E6B`; bilingual PT-BR/EN UI;
  adjectives: *preciso/instrumento, confiável/privado, rápido/técnico, caloroso/pessoal, nerd/open source*.
- No codebase, Figma file, screenshots, brand fonts or logo files were supplied. Everything here was
  authored from scratch against that brief. See **Caveats** at the bottom.

## The design thesis

Ouvi is an **instrument**, not a workspace. It is closer to a tape machine or a field recorder with a
good screen than to a SaaS dashboard. Three consequences that govern every decision:

1. **The transcript is the product.** Type is sized and spaced for reading long verbatim speech, not
   for filling a marketing hero. Nothing decorative may compete with the text column.
2. **Green means local and listening.** One accent, one meaning. Recording state, live draft text,
   "this ran on your Mac" — all green. Everything else is neutral. Cloud usage is amber, and it is
   the only warm color in the app.
3. **Native mechanics, own voice.** Sizes, hit areas, sidebar behaviour, sheets, vibrancy and shortcut
   conventions are macOS-standard (13px UI baseline, 28px controls, hairline dividers). The
   personality comes only from typography and the green — never from custom chrome.

---

## CONTENT FUNDAMENTALS

**Voice: a competent friend who runs your recorder.** Plain, short, specific. It never sells and never
apologizes. It sounds like a person who read the manual, not like a brand.

**Person.** The app speaks to the user as **you** (`Você`), and refers to itself in third person only
when necessary (`O Ouvi transcreveu 41 min`). Never "we" — there is no company behind it, it is a tool
on your disk. The user's own audio channel is labeled **`Você` / `You`**, never "Speaker 1".

**Bilingual rule.** UI is PT-BR and EN with full parity. Portuguese is the reference language; English
strings are written from the Portuguese intent, not translated word-for-word. Never mix languages in one
screen. Product nouns stay untranslated in both: *Ouvi, vault, transcript, Enhance, MCP, hotkey, pill*.

**Casing.** Sentence case everywhere — buttons, menus, titles, dialogs (`Gravar reunião`, not
`Gravar Reunião`). ALL-CAPS is reserved for micro labels with `--tracking-label` (`LOCAL`, `AO VIVO`,
`RASCUNHO`). Never all-caps a full sentence.

**Numbers and machine facts are mono.** Timecodes `00:14:22`, durations `41 min`, model names
`parakeet-tdt-0.6b-v3`, WER `2,5%`, file paths `~/Ouvi/2026/08`, keycaps `⌘⇧O`. This is the single
strongest verbal signal in the product: if it was measured, it is in Space Mono.

**Length.** Buttons 1–3 words. Empty states 1 sentence + 1 action. Settings help text max 2 lines.
Errors say what happened, then what to do, in that order, in one sentence each:
`O microfone está bloqueado. Abra Ajustes do Sistema → Privacidade → Microfone.`

**Privacy copy is factual, never boastful.** State the mechanism, not the virtue.
Good: `Transcrição feita neste Mac. Nada saiu do dispositivo.`
Bad: `Sua privacidade é nossa prioridade.`
When the cloud *is* used, say exactly what left: `Resumo gerado pela Claude API — apenas o texto do transcript foi enviado.`

**Consent, always in the user's words.** `Avise que você está gravando` — a nudge, not a legal wall.

**No emoji. Anywhere.** Not in UI, not in the README, not in release notes. Status is carried by the
green dot, mono labels and Lucide glyphs.

**Copy examples (PT / EN)**

| Context | PT-BR | EN |
|---|---|---|
| Primary action | `Gravar` | `Record` |
| Live badge | `AO VIVO · 12:04` | `LIVE · 12:04` |
| Draft transcript | `rascunho — refinando ao final` | `draft — refined when you stop` |
| Enhance button | `Melhorar notas` | `Enhance notes` |
| Empty search | `Nada ainda. Grave uma reunião ou solte um arquivo de áudio aqui.` | `Nothing yet. Record a meeting or drop an audio file here.` |
| Local badge tooltip | `Tudo neste Mac` | `All on this Mac` |
| Cloud badge | `Nuvem usada nesta reunião` | `Cloud used in this meeting` |
| Dictation ready | `Fale.` | `Speak.` |
| Speaker unnamed | `Falante 2 — dar nome` | `Speaker 2 — name them` |

---

## VISUAL FOUNDATIONS

### Color
Two themes carry equal weight — dark is not an afterthought, and neither is light.
**Light ("paper")** is a warm off-white `#fbfbf9` window with pure-white raised surfaces; the sidebar is
*darker* than the content, macOS-style. **Dark ("graphite")** is `#121315` with `#1a1c1f` surfaces —
never pure black, never blue-tinted. Text is `#16181a` / `#f1f2f2`, i.e. never `#000` / `#fff`.

The palette is deliberately tiny: one neutral ramp, one accent, three status colors.
`--accent` = signal green `#2E9E6B` (light) / `#3fb87f` (dark). It appears on: the record button, the
live dot and waveform, selected rows, focus rings, links, and the `LOCAL` badge. Nothing else.
`--caution` amber is only ever the cloud badge. `--danger` red only appears on destructive confirms
(delete recording, revoke key). `--info` blue is not used in the app chrome at all; it exists for
speaker color 1.

**Speaker colors** are a fixed 5-slot set (`--speaker-me` green, then blue, ochre, violet, teal) used
only as 3px name-side rules and small dots in the transcript — never as text color, never as fills.

### Typography
**Chivo** (grotesk, 300–900) for everything human; **Space Mono** for everything measured.
The UI baseline is **13px** — this is a Mac app, not a website. Reading transcript is 14px/1.68.
Marketing display goes big and heavy (`--type-hero`, 900 weight, `-0.03em`) because Chivo Black is the
brand's loudest asset and the only place we allow loud. Uppercase micro labels use 10px/500 with
`0.08em` tracking. Never letterspace lowercase text.

### Layout
Three columns in the app: sidebar `248px` (fixed), content (fluid, reading measure `68ch`), transcript
rail `340px` (collapsible). Titlebar `38px`, toolbar `44px`, list rows `30px` (compact) or `56px`
(session cards). Gutters come from the 4px grid; chrome uses 8/12/16, reading uses 20/24/32.
The site uses a `1120px` max width, single column, generous vertical rhythm (`--space-12`).

### Backgrounds and texture
Flat surfaces. **No gradients as decoration** — the only gradients allowed are protection fades
(a `--bg-surface` → transparent 24px fade at the top/bottom of scrolling transcript columns) and the
subtle `--live-glow` ring around an active record button. No photographic hero images, no illustration
system, no patterns. Where imagery is needed (site screenshots, docs figures) it is a **real app
screenshot**, and until real screenshots exist, a striped placeholder with a mono caption saying what
belongs there (`app window — main view`). Never hand-drawn SVG scenery.

### Transparency and blur
Reserved for two surfaces, both of which sit over other apps: the **menu-bar dropdown** and the
**dictation pill**, using `--vibrancy-tint` + `--blur-hud` (`saturate(160%) blur(32px)`). In-window
panels are opaque. Never blur behind body text.

### Borders, dividers, shadows
Hairlines do most of the work: `--border-hairline` at `0.09` alpha, drawn as `0.5px` rings inside
shadows so they stay crisp on Retina. Shadows are two-part — a `0.5px` ring for definition plus a soft
drop for lift — and there are exactly five levels: `control`, `card`, `raised`, `popover`, `sheet/hud`.
Cards are `--radius-lg` (10px), hairline ring, `--shadow-card`, no border-left accent stripes, ever.
Controls are 5px, windows and sheets 12–14px, pills fully round.

### States
- **Hover:** a neutral wash (`--bg-hover`, 4.5% ink) — not a color change, not a lift. Filled accent
  buttons darken one step (light) / lighten one step (dark).
- **Press:** `--bg-active` plus `transform: scale(0.985)` on filled controls only. Nothing shrinks more.
- **Focus:** `--focus-ring` (3px green at 32%), always visible for keyboard, never for mouse
  (`:focus-visible`).
- **Selected:** `--bg-selected` (green tint) + medium weight text. Selection survives losing focus by
  dropping to `--bg-active`.
- **Disabled:** 40% opacity, no cursor change beyond `default`. Never gray-on-gray custom colors.

### Motion
Short and mechanical: 120ms for controls, 180ms for surfaces, 220ms for the HUD, `--ease-out`
`cubic-bezier(0.2,0.7,0.3,1)`. **Nothing bounces, nothing overshoots, nothing spins except a spinner.**
Panels fade + rise 4px (`ouvi-fade-up`). The live dot pulses at 1.2s. The waveform is the only
continuous animation in the product, and it is driven by real amplitude, never faked when idle.
`prefers-reduced-motion` kills all of it except the waveform.

### Sound and status vocabulary
A single green dot with a soft glow means *listening now*. A hollow green ring means *armed*. Mono
`RASCUNHO` next to text means *not final*. Gray italic-free light text (`--text-draft`) is unrefined ASR
output; it turns to `--text-body` when pass 2 lands. AI-added content in notes is `--text-muted` with a
mono citation chip; the user's own bullets are always full-contrast `--text-body`.

---

## ICONOGRAPHY

**Lucide** (ISC license), stroke `1.5`, 16px in chrome / 20px in HUD and empty states, currentColor.
No brand icon set was supplied, so this is a flagged substitution: Lucide was chosen because its
geometric, thin, unrounded stroke matches Chivo and the SF Symbols density of a native Mac app.

Delivery: icons are loaded from the `lucide-static` CDN
(`https://cdn.jsdelivr.net/npm/lucide-static@latest/icons/<name>.svg`) through the `Icon` component, which paints
them with `background: currentColor; mask: url(...)` so a single URL inherits text color in both themes.
For offline/production use, vendor the same files into `assets/icons/` and point `Icon`'s `base` prop at
that folder — the component takes the base path as a prop for exactly this reason.

Working set: `mic`, `mic-off`, `square` (stop), `circle` (record), `audio-lines` (waveform),
`play`, `pause`, `search`, `calendar`, `users`, `user`, `building-2`, `folder`, `file-text`,
`sparkles` (Enhance), `message-square` (chat), `link`, `check`, `x`, `chevron-right`, `chevron-down`,
`settings`, `shield-check` (local/privacy), `cloud`, `keyboard`, `command`, `download`, `trash-2`,
`plug` (MCP), `github`.

**Emoji: never.** **Unicode as icons:** only for keycaps inside `Kbd` (`⌘ ⇧ ⌥ ⌃ ⏎ ␣ fn`) and the
middle dot `·` as a metadata separator. Status is never conveyed by a glyph alone — always glyph +
label, or color + label.

**No logo exists.** No mark, wordmark or icon file was provided, and none was drawn. Wherever a logo
would go, Ouvi is set in **Chivo 900, `-0.03em`, `--text-title`**, lowercase `ouvi`, optionally
followed by a 6px green dot as the "listening" mark. Replace this with the real mark when it exists;
`assets/wordmark.html` shows the exact treatment.

---

## Index

- `styles.css` — the single entry point consumers link. `@import` list only.
- `tokens/` — `fonts`, `colors`, `typography`, `spacing`, `radius`, `elevation`, `motion`, `base`.
- `guidelines/` — 17 foundation specimen cards (groups: Type, Colors, Spacing, Motion, Brand).
- `components/` — `core/`, `forms/`, `navigation/`, `feedback/`, `meeting/`, `dictation/`.
- `ui_kits/desktop_app/` — the macOS app: main window, dictation HUD, menu bar, onboarding, settings,
  search + chat, person page.
- `ui_kits/website/` — the open-source landing page and docs page.
- `assets/` — wordmark treatment and image-placeholder pattern (icons come from the Lucide CDN).
- `SKILL.md` — portable Agent Skill wrapper (works as a Claude Code skill if you download this folder).

### Starting points

- `components/core/Button.d.ts` → Core primitives
- `components/meeting/RecordButton.d.ts` → Meeting primitives
- `components/dictation/DictationPill.d.ts` → Dictation HUD
- `ui_kits/desktop_app/index.html` → the full macOS app recreation
- `ui_kits/website/index.html` → landing page + docs

### Component inventory

| Group | Components |
|---|---|
| `core` | `Button`, `IconButton`, `Icon`, `Kbd`, `Badge`, `Tag`, `Card` |
| `forms` | `Input`, `SearchField`, `Select`, `Checkbox`, `Switch`, `SegmentedControl` |
| `navigation` | `SidebarItem`, `Tabs`, `Toolbar` |
| `feedback` | `Toast`, `Tooltip`, `ProgressBar`, `EmptyState` |
| `meeting` | `RecordButton`, `Waveform`, `TranscriptLine`, `SpeakerChip`, `TimeCode`, `Citation`, `SessionRow`, `PrivacyBadge` |
| `dictation` | `DictationPill` |

**Intentional additions** (no source defined a component list, so the set was authored from the product
spec): `Icon` exists purely as the Lucide mask wrapper; `PrivacyBadge`, `Citation`, `TimeCode`,
`Waveform` and `DictationPill` are product-specific primitives that the app's core promises
(local-only, cited AI, seekable audio, dictation) require to be consistent everywhere.

## Caveats

- No logo, brand fonts, screenshots, Figma file or codebase were available. Type pair (Chivo /
  Space Mono), the neutral ramps, and the icon set are authored proposals, not brand facts.
- Fonts load from the Google Fonts CDN. If you want self-hosted binaries or different families, say so.
- Icons are a flagged Lucide substitution.
- App screenshots in the website kit are striped placeholders with mono captions.
