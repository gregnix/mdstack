# mdstack -- Markdown Stack for Tcl/Tk

A complete Markdown processing stack for Tcl/Tk applications.

**Version:** 0.3.3  
**Status:** Stable

---

## Modules

### Core

| Module | Version | Description |
|--------|---------|-------------|
| `mdparser` | 0.2 | Markdown → AST parser (CommonMark subset + TIP-700) |
| `mdstack` | 0.1 | Orchestrator / stack manager |
| `mdmodel` | 0.1 | Document model |
| `mdvalidator` | 0.1 | AST validator |

### Renderers

| Module | Version | Description |
|--------|---------|-------------|
| `mdviewer` | 0.3 | Markdown viewer (Tk text widget) |
| `mdpdf` | 0.2 | Markdown → PDF (via pdf4tcl) |
| `mdhtml` | 0.1 | Markdown → HTML |
| `docir-md` | 0.1 | mdparser AST → DocIR intermediate representation |

### UI

| Module | Version | Description |
|--------|---------|-------------|
| `mdtext` | 0.1 | Editor widget |
| `mdsearch` | 0.1 | Full-text search in viewer |
| `mdoutline` | 0.1 | Document outline panel |
| `mdcontextmenu` | 0.1 | Context menu |
| `mdeditor` | 0.1 | Editor (legacy) |
| `mdeditorkit` | 0.2 | Editor kit (legacy) |
| `mdeditwidget` | 0.2 | Edit widget (legacy) |

### Themes & Styling

| Module | Version | Description |
|--------|---------|-------------|
| `mdtheme` | 0.1 | Shared theme system (HTML, PDF, Tk) |

### Tools

| Tool | Description |
|------|-------------|
| `tools/mdserver/mdserver.tcl` | HTTP/HTTPS Markdown web server |
| `tools/mdserver/mkcert.tcl` | TLS certificate helper |

---

## Requirements

- Tcl 8.6+ (Tcl 9.x compatible)
- Tk 8.6+  (for mdviewer, mdtext and UI modules)
- pdf4tcl  (for mdpdf -- optional)
- tls      (for mdserver HTTPS -- optional)

---

## Quick Start

### Tk Viewer

```tcl
tcl::tm::path add /path/to/mdstack-0.3.x/lib
package require mdparser 0.2
package require mdviewer 0.3

set ast [mdparser::parse "# Hello\n\nWorld."]
mdviewer::create .v -width 600 -height 400
mdviewer::render .v $ast
pack .v
```

### HTML Export

```tcl
package require mdparser 0.2
package require mdhtml   0.1
package require mdtheme  0.1

set ast [mdparser::parse $markdown]
mdhtml::export $ast output.html -theme light -toc 1
```

### PDF Export

```tcl
package require mdpdf 0.2

mdpdf::exportFile input.md output.pdf -title "My Document" -toc 1
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
