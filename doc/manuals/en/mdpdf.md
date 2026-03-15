# mdpdf

> Version 0.2 – pdf4tcllib backend

## Purpose

`mdpdf` exports Markdown documents as PDF files.

The module:
- converts a Markdown AST or model to PDF
- supports all block types (headings, paragraphs, lists, code, blockquotes, HR)
- generates a table of contents (TOC)
- renders blockquotes with italic formatting
- handles Unicode sanitization and Emoji fallbacks via pdf4tcllib

---

## Supported elements

| Element | Rendering |
|---------|-----------|
| Headings h1–h6 | Font size + bold |
| Paragraphs | Text with wrapping |
| Lists (ul/ol) | Indent + bullet/number |
| Nested lists | Visual indentation, arbitrary depth |
| Task lists | `[x]` / `[ ]` markers |
| Code blocks | Monospace font |
| Blockquotes | Indent + italic text |
| Tables | Column widths with alignment |
| Images | Image rendering with alt-text fallback |
| Horizontal rule | `---` |
| TOC | Auto-generated (without page numbers) |
| Hyperlinks | Clickable PDF annotations |

**Inline formatting:** bold, italic, code, combinations

---

## Dependencies

- Tcl ≥ 8.6
- pdf4tcl 0.9+
- pdf4tcllib 0.1
- mdparser 0.2 (optional, for AST input)
- mdmodel 0.1 (optional, for model input)

---

## Public API

### `mdpdf::exportFile mdFile outputFile ?options?`

Reads a Markdown file and exports it as PDF.
**Recommended API for files with Emojis and special characters.**

Reads the file binary and replaces Emoji bytes (4-byte UTF-8) with
ASCII fallbacks before Tcl 8.6 can corrupt them to U+FFFD.

```tcl
package require mdpdf 0.2

mdpdf::exportFile "input.md" "output.pdf" \
    -title "Documentation" \
    -toc 1 \
    -fontsize 11 \
    -footer "Page %p"
```

---

### `mdpdf::export ast outputFile ?options?`

Exports an AST as PDF.

```tcl
set ast [mdparser::parse $markdown]
mdpdf::export $ast "output.pdf" -title "Documentation" -toc 1
```

---

### `mdpdf::exportModel doc outputFile ?options?`

Exports an mdmodel document model as PDF.

```tcl
set doc [mdmodel::new $ast]
mdpdf::exportModel $doc "output.pdf" -title "Documentation"
```

---

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `-title` | `""` | Title on first page |
| `-pagesize` | `A4` | Page size (A4, Letter) |
| `-margin` | `50` | Margin in points |
| `-fontsize` | `11` | Base font size |
| `-toc` | `0` | Table of contents (0\|1) |
| `-header` | `""` | Header text |
| `-footer` | `"- %p -"` | Footer text (`%p` = page number) |
| `-root` | `""` | Base path for relative image URLs |
| `-fontdir` | `""` | Directory with TTF font files |
| `-debug` | `0` | Debug output (0\|1) |
| `-compress` | `1` | zlib compression (0\|1) |
| `-pdfa` | `""` | PDF/A conformance: `1b`, `2b` (pdf4tcl 0.9.4.11+) |
| `-userpassword` | `""` | AES-128 user password |
| `-ownerpassword` | `""` | AES-128 owner password |
| `-theme` | `""` | mdtheme name: `hell`, `dunkel`, `solarized` |

---

### `mdpdf::configure ?options?`

Sets global defaults.

```tcl
mdpdf::configure -fontsize 12 -margin 60
```

---

## Features

### Hyperlinks (0.2)

Markdown links `[Label](URL)` are embedded as clickable PDF annotations.

### PDF/A export (0.2)

```tcl
mdpdf::export $ast output.pdf -pdfa 1b  ;# PDF/A-1b
mdpdf::export $ast output.pdf -pdfa 2b  ;# PDF/A-2b
```

### Encryption (0.2)

```tcl
mdpdf::export $ast output.pdf -userpassword "secret"
mdpdf::export $ast output.pdf -ownerpassword "admin"
```

### Theme support (0.2)

```tcl
mdpdf::export $ast output.pdf -theme hell
mdpdf::export $ast output.pdf -theme dunkel
```

---

## Limitations

- TOC page numbers not yet implemented (requires two-pass export)
- Theme colors in PDF pending pdf4tcl 0.9.4.12
- Strikethrough rendered as normal text

---

## See also

- [mdhelp_pdf](mdhelp_pdf.md) – widget-based PDF export
- [pdf4tcllib](pdf4tcllib.md) – PDF extension library
- [mdparser](mdparser.md) – Markdown parser
