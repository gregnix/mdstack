# mdstack — module status

Inventory of the `lib/mdstack/*.tm` submodules, their dependency tier, and their
test/doc coverage. This is the engineering-parity baseline (the level
tclutils/tkutils already hold): it makes the gaps explicit.

`mdstack-0.1.tm` itself is the **orchestrator** (context stack, callback-based);
by design it knows no concrete modules and is intentionally *not* a loader.

## Modules

| module | ver | tier | declared requires | dedicated test | doc |
|--------|-----|------|-------------------|----------------|-----|
| parser | 0.2 | core | *(none)* | indirect | — |
| model | 0.1 | core | *(none)* | indirect | — |
| theme | 0.1 | core | *(none)* | — | — |
| text | 0.1 | Tk\* | *(none)* | indirect | — |
| viewer | 0.3 | Tk | Tk · *opt:* tkutils::tkuwheel, Img, tksvg | **viewer.tcl** | — |
| outline | 0.1 | Tk | Tk, mdstack::text 0.1 | — | — |
| search | 0.1 | Tk | Tk (+ self-require — review) | indirect | — |
| contextmenu | 0.1 | Tk | Tk, mdstack::uicontextmenu 0.1 | indirect | — |
| uicontextmenu | 0.1 | Tk | Tk | indirect | — |
| editorkit | 0.2 | Tk | Tk, mdstack::{text,parser 0.2,model,viewer 0.3} | indirect | — |
| validator | 0.1 | core | *(self-require — review)* | **validator.tcl** | — |
| html | 0.1 | export | docir::mdSource, docir::html | indirect | — |
| pdf | 0.2 | export | docir::mdSource, docir::pdf, pdf4tcllib, mdstack::parser | indirect | — |
| stacknoteskit | 0.1 | glue | noteskit 0.1, mdstack 0.1 (+ self-require — review) | — | — |

Tiers: **core** = pure Tcl, no Tk; **Tk** = needs Tk; **export** = needs docir
(html/pdf rendering); **glue** = ties the orchestrator to a data source.
`Tk*` = used as a widget but does not declare `package require Tk`.

## Parity gaps (vs tclutils/tkutils)

1. **Missing version pins.** parser, model, theme, text declare no
   `package require Tcl 8.6-` (and text/several GUI modules omit
   `package require Tk 8.6-`). tclutils/tkutils mandate both. Adding them is
   cheap and prevents silent runs on incompatible interpreters.
2. **No per-module docs.** `docs/manuals/` is empty; there is no `docs/<mod>.md`
   single source and no man-page pipeline as in tkutils. The parser/viewer/html
   public APIs are the highest-value to document first.
3. **Thin dedicated test coverage.** Only `viewer` and `validator` have their own
   test files. `outline`, `stacknoteskit`, `theme` have no coverage even
   indirectly; the rest are only exercised through parser/other suites.
4. **Suspicious self-requires.** `search`, `validator`, and `stacknoteskit`
   appear to `package require` their own package name — worth reviewing for a
   copy/paste artefact or an intended split.
5. **No version-pinned loader.** Because the deps are heterogeneous (core / Tk /
   docir), a single "require everything" umbrella would force Tk *and* docir on
   every consumer. A **tiered** loader is the clean option, e.g.
   `mdstack::core` (parser, model, theme), `mdstack::ui` (the Tk widgets), and
   `mdstack::export` (html, pdf → docir). This keeps the orchestrator untouched
   and lets mdhelp/pdf2img pull only the tier they need. **Decision needed**
   before scaffolding.

## Suggested order

Pin versions (1) and add tests for the three untested modules (3) first — both
are low-risk and immediately raise the floor. Per-module docs (2) can follow the
tkutils single-source-`md` + `md2man` pattern. The tiered loader (5) and the
self-require review (4) are small once the structure is decided.
