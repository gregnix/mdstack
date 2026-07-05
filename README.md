# mdstack -- Markdown Stack for Tcl/Tk

A complete Markdown processing stack for Tcl/Tk applications.

**Version:** 0.6.0  
**Status:** Stable

---

## Modules

### Core

| Module | Version | Description |
|--------|---------|-------------|
| `mdstack::parser` | 0.6.3 | Markdown → AST parser (CommonMark subset + TIP-700) |
| `mdstack` | 0.1 | Orchestrator / stack manager |
| `mdstack::model` | 0.1 | Document model |
| `mdstack::validator` | 0.1 | AST validator |

### Renderers

| Module | Version | Description |
|--------|---------|-------------|
| `mdstack::viewer` | 0.4 | Markdown viewer (Tk text widget) |
| `mdstack::pdf` | 0.2 | Markdown → PDF *(adapter to DocIR pipeline since May 2026)* |
| `mdstack::html` | 0.1 | Markdown → HTML *(adapter to DocIR pipeline since May 2026)* |

> **Naming note (May 2026):** All mdstack modules use the consistent
> `mdstack::*` namespace (formerly `::mdparser`, `::mdtext`, etc.).
> Module name and Tcl namespace now match. See CHANGES for migration details.

### DocIR bridge

mdstack is a consumer of the [docir repo](../docir/). Three DocIR
components are used directly:

| External module | Source | Purpose |
|-----------------|--------|---------|
| `docir::mdSource` | docir repo | mdparser AST → DocIR |
| `docir::rendererTk` | docir repo | DocIR → Tk text widget |
| `docir::html` | docir repo | DocIR → HTML *(internally via the mdstack::html adapter)* |

The application using mdstack must arrange for docir to be on its
`tcl::tm::path` (e.g. system install under
`/usr/local/lib/tcltk/docir/`, user install at `~/lib/tcltk/docir/`,
or `$DOCIR_HOME` set explicitly). The mdstack-test setup helper
`tests/_paths.tcl` shows the search order used for development from
a sibling-repo checkout.

#### mdhtml consolidation (Phase 2 Session 7, 2026-05-06)

`mdhtml-0.1.tm` has been an **adapter** to the DocIR pipeline since May 2026:

```
mdparser → mdstack::html::render → docir::md::fromAst
                          → docir::html::render
                          → HTML
```

The public API is backwards-compatible — callers (mdserver, demos)
need no changes. The original V0.1 was removed after the Phase 2
cutover in May 2026; git history retains it for reference.

**Benefits of the consolidation:**
- Code duplication removed (~600 lines were parallel to docir::html)
- Full Markdown coverage from DocIR spec 0.5 (strike, image, linebreak,
  span, footnote_ref, div) automatically available
- New features come centrally from the docir repo
- Asset copy: `exportFile` copies referenced images along with output (since 2026-05)

#### mdpdf consolidation (Phase 3 Session 5, 2026-05-06)

`mdpdf-0.2.tm` has likewise been an **adapter** to the DocIR pipeline
since May 2026 (177 lines instead of 1786):

```
mdparser → mdstack::pdf::export → docir::md::fromAst
                         → docir::pdf::render
                         → PDF
```

The public API is backwards-compatible. The original V0.2 was removed
after the Phase 3 cutover; git history retains it. **Deliberately NOT ported:** PDF/A,
AES-128 encryption, automatic TOC with PDF outlines. 

**What docir::pdf gained in Phase 3:**
- TTF font embedding (DejaVu, Unicode support)
- Per-inline style switching (bold/italic/code/strike distinguishable)
- Clickable PDF hyperlinks
- Header/footer templates with `%p` substitution
- Theme colours (colorLink, colorCode)
- Image embedding via `pdf4tcl::addImage` (Tk-free)

#### mdviewer and mdtext NOT consolidated

mdviewer is a Tk widget with its own lifecycle (anchor marks, click
dispatch, per-instance state) — not a pure render function. mdtext is
an editor widget. Both remain standalone.

### UI

| Module | Version | Description |
|--------|---------|-------------|
| `mdstack::text` | 0.1 | Editor widget |
| `mdstack::search` | 0.1 | Full-text search in viewer |
| `mdstack::outline` | 0.1 | Document outline panel |
| `mdstack::contextmenu` | 0.1 | Context menu |
| `mdstack::uicontextmenu` | 0.1 | UI context menu helpers |
| `mdstack::editorkit` | 0.2 | Editor kit (legacy) |
| `mdstack::stacknoteskit` | 0.1 | Stack-notes UI kit |

### Themes & Styling

| Module | Version | Description |
|--------|---------|-------------|
| `mdstack::theme` | 0.1 | Shared theme system (HTML, PDF, Tk) |

### Tools

| Tool | Description |
|------|-------------|
| `tools/mdserver/mdserver.tcl` | HTTP/HTTPS Markdown web server |
| `tools/mdserver/mkcert.tcl` | TLS certificate helper |

---

## Requirements

- **Tcl 8.6+** (Tcl 9.x compatible)
- **Tk 8.6+** -- for `mdstack::viewer`, `mdstack::text`, UI modules
- **docir** (sibling repo or system install) -- for `mdstack::html` and `mdstack::pdf`
- **pdf4tcl 0.9.4+** -- for `mdstack::pdf` (optional, PDF tests skip otherwise)
- **pdf4tcllib 0.1+** -- for `mdstack::pdf` emoji/font handling
- **tls 1.7+** -- for `mdserver` HTTPS (optional)

### Consumer matrix

| Module | Hard dep | Soft dep |
|--------|----------|----------|
| `mdstack::parser` | -- | -- |
| `mdstack::model` | -- | -- |
| `mdstack::validator` | -- | -- |
| `mdstack::viewer` | Tk | docir::rendererTk (recommended) |
| `mdstack::html` | `docir::mdSource`, `docir::html` | -- |
| `mdstack::pdf` | `docir::mdSource`, `docir::pdf`, `pdf4tcl` | `pdf4tcllib` |
| `mdstack::text` | Tk | -- |

If a soft/hard dep is unavailable, the affected tests self-skip
rather than crash the runner. See `tests/_paths.tcl` for how docir
is located during development.

---

## Quick Start

### Tk Viewer

```tcl
tcl::tm::path add /path/to/mdstack/lib
package require mdstack::parser 0.2
package require mdstack::viewer 0.3

set ast [mdstack::parser::parse "# Hello\n\nWorld."]
mdstack::viewer::create .v -width 600 -height 400
mdstack::viewer::render .v $ast
pack .v
```

### HTML Export

```tcl
package require mdstack::parser 0.2
package require mdstack::html   0.1
package require mdstack::theme  0.1

set ast [mdstack::parser::parse $markdown]
mdstack::html::export $ast output.html -theme light -toc 1
```

### PDF Export

```tcl
package require mdstack::pdf 0.2

mdstack::pdf::exportFile input.md output.pdf -title "My Document" -toc 1
```

### Web Server

```bash
cd tools/mdserver
tclsh mdserver.tcl --root /path/to/docs --port 8080
# with HTTPS:
tclsh mdserver.tcl --root /path/to/docs --cert server.crt --key server.key
```

---

## Tests

```bash
cd tests

# All available groups (auto-detects Tk and pdf4tcl):
tclsh all.tcl

# Core/Parser only (headless, no Tk needed):
tclsh all.tcl --core

# GUI tests only (requires Tk):
tclsh all.tcl --gui

# PDF/Export tests only (requires pdf4tcl):
tclsh all.tcl --pdf
```

Without external deps (`--core` only, no Tk, no docir, no pdf4tcl):
**532 tests passing**. Tests that depend on docir, pdf4tcl, or Tk
self-skip with a clear message rather than crashing the runner.

With docir installed: additional ~50 renderer tests via `mdstack::html`
adapter. With Tk: additional ~21 GUI tests. With pdf4tcl: additional
PDF tests.

---

## Directory Structure

```
mdstack-0.3.x/
  lib/           -- Tcl modules (.tm) -- mdstack-0.1.tm + mdstack/*.tm
  demo/          -- Demo scripts and examples
  tests/         -- Test suite (group A core, B renderer, C GUI, D PDF)
  doc/
    manuals/     -- Module documentation
  tools/
    mdserver/    -- HTTP/HTTPS Markdown server (uses tls if available)
    generate-pkgindex.tcl -- regenerate lib/pkgIndex.tcl
    nroff2md.tcl          -- nroff to Markdown converter (uses TIP-700)
```

*(No `vendors/` subtree -- since 2026-05 all dependencies (`docir`,
`pdf4tcl`, `pdf4tcllib`) are loaded via standard `package require`.)*

---

## License

MIT -- see [LICENSE](LICENSE)

---

## Links

- pdf4tcl: https://github.com/gregnix/pdf4tcl
