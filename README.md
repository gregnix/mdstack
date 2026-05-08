# mdstack -- Markdown Stack for Tcl/Tk

A complete Markdown processing stack for Tcl/Tk applications.

**Version:** 0.3.4  
**Status:** Stable

---

## Modules

### Core

| Module | Version | Description |
|--------|---------|-------------|
| `mdstack::parser` | 0.2 | Markdown → AST parser (CommonMark subset + TIP-700) |
| `mdstack` | 0.1 | Orchestrator / stack manager |
| `mdstack::model` | 0.1 | Document model |
| `mdstack::validator` | 0.1 | AST validator |

### Renderers

| Module | Version | Description |
|--------|---------|-------------|
| `mdstack::viewer` | 0.3 | Markdown viewer (Tk text widget) |
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

The docir repo is found automatically via `lib/docir-loader.tcl`
(sibling, `$DOCIR_HOME`, or `auto_path` lookup).

#### mdhtml consolidation (Phase 2 Session 7, 2026-05-06)

`mdhtml-0.1.tm` has been an **adapter** to the DocIR pipeline since May 2026:

```
mdparser → mdstack::html::render → docir::md::fromAst
                          → docir::html::render
                          → HTML
```

The public API is backwards-compatible — callers (mdserver, demos)
need no changes. The original V0.1 implementation lives on as a
`mdhtml-0.1.tm.legacy` backup if needed.

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

The public API is backwards-compatible. Original V0.2 kept as a
`mdpdf-0.2.tm.legacy` backup. **Deliberately NOT ported:** PDF/A,
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

- Tcl 8.6+ (Tcl 9.x compatible)
- Tk 8.6+  (for mdstack::viewer, mdstack::text and UI modules)
- pdf4tcl  (for mdstack::pdf -- optional)
- tls      (for mdserver HTTPS -- optional)

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

Headless (no Tk): **445 tests, 0 failures**  
With Tk: additional 21 GUI tests

---

## Directory Structure

```
mdstack-0.3.x/
  lib/           -- Tcl modules (.tm)
  demo/          -- Demo scripts and examples
  tests/         -- Test suite
  doc/
    manuals/     -- Module documentation
  tools/
    mdserver/    -- HTTP/HTTPS Markdown server
  vendors/
    tm/          -- Vendor modules (pdf4tcllib)
```

---

## License

MIT -- see [LICENSE](LICENSE)

---

## Links

- pdf4tcl: https://github.com/gregnix/pdf4tcl
