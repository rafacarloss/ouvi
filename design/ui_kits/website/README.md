# UI kit — ouvi.app (open-source site)

Two surfaces, built from the same tokens and primitives as the app: the landing page and the docs page.
Open `index.html`; the top nav switches between them and the moon control switches theme.

| File | Surface |
|---|---|
| `Site.jsx` | Shell: header, nav, footer, theme toggle |
| `Landing.jsx` | Hero, how it works, privacy proof, dictation, knowledge base, MCP, download |
| `Docs.jsx` | Docs layout: sidebar, prose, mono code blocks, permissions table |
| `Placeholder.jsx` | Striped image placeholder with a mono caption (stands in for real screenshots) |

Notes
- Product screenshots do not exist yet. Every image slot is a `Placeholder` saying exactly what belongs
  there — replace them with real app captures before publishing.
- The site is deliberately plain: one column, `1120px` max width, no marketing gradients, Chivo Black
  for the hero and Space Mono for anything measured.
