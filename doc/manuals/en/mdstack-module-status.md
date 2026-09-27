# mdstack — module status

Inventory of the `lib/mdstack/*.tm` submodules, their dependency tier, and their
test/doc coverage. This is the engineering-parity baseline (the level
tclutils/tkutils already hold): it makes the gaps explicit.

**Stand:** 2026-09-26 (measured `package provide` in `mdstack/lib/`).

`mdstack-0.1.tm` itself is the **orchestrator** (context stack, callback-based);
by design it knows no concrete modules and is intentionally *not* a loader.

## Modules

| module | ver | tier | declared requires | dedicated test | doc |
|--------|-----|------|-------------------|----------------|-----|
| parser | 0.8.0 | core | Tcl 8.6- | parser suites | parser.md |
| model | 0.1 | core | Tcl 8.6- | indirect | model.md |
| theme | 0.1 | core | Tcl 8.6- | — | theme.md |
| validator | 0.1 | core | Tcl 8.6- | **validator.tcl** | validator.md |
| indexgen | 0.1 | core | Tcl 8.6 9 | — | mdindexgen.md |
| text | 0.1 | Tk | Tcl 8.6-, Tk 8.6- | indirect | — |
| viewer | 0.4 | Tk | Tcl 8.6-, Tk 8.6-; *opt:* tkutils::tkuwheel, Img, tksvg | **viewer.tcl** | viewer.md |
| outline | 0.1 | Tk | Tcl 8.6-, Tk 8.6-, mdstack::text 0.1 | — | outline.md |
| search | 0.1 | Tk | Tcl 8.6-, Tk 8.6- | indirect | search.md |
| contextmenu | 0.1 | Tk | Tcl 8.6-, Tk 8.6-, mdstack::uicontextmenu 0.1 | indirect | contextmenu.md |
| uicontextmenu | 0.1 | Tk | Tcl 8.6-, Tk 8.6- | indirect | — |
| editorkit | 0.2 | Tk | Tcl 8.6-, Tk 8.6-, mdstack::{text,parser 0.2,model,viewer 0.3} | indirect | editorkit.md |
| html | 0.2 | export | docir::mdSource, docir::html | indirect | html.md |
| pdf | 0.3 | export | docir::mdSource, docir::pdf 0.3, pdf4tcllib | indirect | pdf.md |
| stacknoteskit | 0.1 | glue | noteskit 0.1, mdstack 0.1 | — | stacknoteskit.md |

Tiers: **core** = pure Tcl, no Tk; **Tk** = needs Tk; **export** = needs docir
(html/pdf rendering); **glue** = ties the orchestrator to a data source.

`mdserver` 0.3 lives under `tools/mdserver/` — not a `mdstack::*` submodule.

## Parser 0.8.0 (measured)

- CommonMark HTML blocks (all 7 start conditions) as `html_block` — previously dropped.
- Display math `$$...$$` → `math_block`; inline `$...$` → `math`.
- `supports` returns a **static** capability list (argument unused). Tokens include
  `blocks:html_block`, `blocks:math_block`, `inline:math`.
- `parser::validate` is a shallow document/version/blocks check. Node walks live
  in `mdstack::validator`.

## Parity gaps (vs tclutils/tkutils)

1. **Version pins — done 2026-09-26.** viewer, outline, search,
   contextmenu, uicontextmenu, editorkit declare `Tcl 8.6-` and `Tk 8.6-`.
   validator declares `Tcl 8.6-`.
2. **Per-module docs — partly present.** `doc/manuals/en/` holds per-module
   manuals including `mdindexgen.md`. Missing versus tkutils: single-source-`md`
   + `md2man` pipeline (these are hand-written, not generated) and man-page
   output.
3. **Thin dedicated test coverage.** Only `viewer` and `validator` have their own
   test files. `outline`, `stacknoteskit`, `theme`, `indexgen` have no coverage
   even indirectly; the rest are only exercised through parser/other suites.
4. **Self-requires — cleared.** Comments still show `package require mdstack::…`
   as usage examples; the live `.tm` files no longer require themselves.
5. **No version-pinned loader.** Because the deps are heterogeneous (core / Tk /
   docir), a single "require everything" umbrella would force Tk *and* docir on
   every consumer. A **tiered** loader is the clean option, e.g.
   `mdstack::core` (parser, model, theme), `mdstack::ui` (the Tk widgets), and
   `mdstack::export` (html, pdf → docir). This keeps the orchestrator untouched.
   **Decision needed** before scaffolding.
6. **Vendor copy.** `mdhelpapp/libs/common/` was synced from the live trees
   on 2026-09-26: tclutils 0.63.0, tkutils 0.44.0, pdf4tcl 0.9.4.67,
   pdf4tcllib 0.6.5, mdstack parser 0.8.0, docir pdf 0.5 / rendererTk 0.5.
   Nested `.git` remotes were left alone. Glyphs-1.5.2 has no live sibling.

## Suggested order

Tests for the untested modules (3) first. Per-module docs (2) can follow the
tkutils single-source-`md` + `md2man` pattern. The tiered loader (5) is small
once the structure is decided. Do not silently overwrite mdhelpapp copies.
