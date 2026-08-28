# UI kit — Ouvi for macOS

High-fidelity recreation of the seven surfaces of the desktop app, built entirely from the
design-system primitives in `components/`. Open `index.html`; the tab strip at the top of the desk
switches surfaces and the sun/moon control switches theme (both themes are first-class).

| File | Surface |
|---|---|
| `Kit.jsx` | The desk: window chrome, surface switcher, theme toggle |
| `MainWindow.jsx` | Sessions list + notes editor + live transcript rail (recording state) |
| `MenuBarPanel.jsx` | Menu-bar dropdown: today's calendar, record, dictation status |
| `DictationHUD.jsx` | Floating dictation pill over another app, in all states |
| `Onboarding.jsx` | The four macOS permissions + vault choice + model download |
| `Settings.jsx` | Models, languages, privacy, hotkeys, dictionary |
| `SearchChat.jsx` | Hybrid search sheet and RAG chat answers with citations |
| `PersonPage.jsx` | Person page: everything ever discussed with someone |

Notes
- Screens are cosmetic recreations: state is local `useState`, data is fixture data, no audio or ASR.
- Copy is PT-BR here; every string has an EN counterpart in `readme.md` → CONTENT FUNDAMENTALS.
- `index.html` transpiles the primitives from source in the browser, so the kit does not depend on
  the compiled bundle. In production code, import the components normally.
