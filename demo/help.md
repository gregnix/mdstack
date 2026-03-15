# Markdown Viewer – Help

## Overview

The **Markdown Viewer** is a full-featured Markdown reader built with mdstack.

---

## Opening files

| Method | Description |
|--------|-------------|
| `Ctrl+O` | Open file dialog |
| `Ctrl+R` | Reload current file |
| Command line | `wish mdviewer-app-v2.tcl file.md` |

Supported formats: `.md`, `.markdown`, `.txt`

Relative links between `.md` files are followed automatically.

---

## Navigation

**Table of Contents** — click any heading in the left panel to jump to it.
Toggle with `Ctrl+T`.

**Anchor links** — internal `#links` in the document navigate directly.

**External links** — open in your default browser.

---

## Search

Press `Ctrl+F` to open the search bar.

| Key | Action |
|-----|--------|
| `Ctrl+F` | Open / close search |
| `Return` | Search forward |
| `↓` | Next match |
| `↑` | Previous match |
| `Escape` | Close search |

Matches are highlighted yellow, the current match orange.
The counter shows `current / total` matches.

---

## Font size

| Shortcut | Action |
|----------|--------|
| `Ctrl++` | Increase font size |
| `Ctrl+-` | Decrease font size |
| `Ctrl+0` | Reset to default (10pt) |

Or use the spinbox in the toolbar.

---

## Export

### PDF export (`Ctrl+P`)

Requires `pdf4tcl`. Exports the current document as PDF with:
- Table of contents
- Page footer with page numbers
- Relative images resolved from file location

### HTML export (`Ctrl+H`)

Exports the current document as HTML with:
- Embedded CSS (responsive layout)
- Table of contents
- Clean semantic markup

---

## Keyboard shortcuts (complete)

| Shortcut | Action |
|----------|--------|
| `Ctrl+O` | Open file |
| `Ctrl+R` | Reload file |
| `Ctrl+P` | Export PDF |
| `Ctrl+H` | Export HTML |
| `Ctrl+F` | Search |
| `Ctrl+T` | Toggle TOC |
| `Ctrl++` | Font larger |
| `Ctrl+-` | Font smaller |
| `Ctrl+0` | Font normal |
| `Escape` | Close search |
| `Ctrl+Q` | Quit |

---

## About mdstack

This viewer is built on the **mdstack** module suite:

| Module | Role |
|--------|------|
| `mdparser 0.2` | Markdown → AST |
| `mdmodel 0.1` | AST → document model |
| `mdviewer 0.3` | Rendering in Tk text widget |
| `mdsearch 0.1` | Full-text search with highlighting |
| `mdpdf 0.2` | PDF export (optional) |
| `mdhtml 0.1` | HTML export (optional) |

Source: [github.com/gregnix/mdstack](https://github.com/gregnix/mdstack)
