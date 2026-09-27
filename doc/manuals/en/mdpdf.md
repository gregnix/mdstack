# mdstack::pdf

> Version 0.3 — adapter to `docir::mdSource` + `docir::pdf` (live 0.5)

## Purpose

`mdstack::pdf` exports Markdown documents as PDF files through DocIR.

The module:
- converts a Markdown AST or model to PDF
- maps options onto `docir::pdf::render`
- generates a TOC when `-toc 1` (two-pass, with page numbers)
- handles Unicode via pdf4tcllib (CID/TTF)

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
| TOC | two-pass via `docir::pdf` `generateToc` (page numbers) |
| Hyperlinks | Clickable PDF annotations |

**Inline formatting:** bold, italic, code, combinations

---

## Dependencies

- Tcl ≥ 8.6
- pdf4tcl 0.9.4+
- pdf4tcllib (live 0.6.5; `docir::pdf` requires ≥ 0.3)
- mdstack::parser 0.8.0 (optional, for AST input)
- mdstack::model 0.1 (optional, for model input)
- `docir::mdSource`, `docir::pdf` 0.3 (pulls 0.5)

---

## Public API

### `mdstack::pdf::exportFile mdFile outputFile ?options?`

Reads a Markdown file and exports it as PDF.
**Recommended API for files with Emojis and special characters.**

Reads the file binary and replaces Emoji bytes (4-byte UTF-8) with
ASCII fallbacks before Tcl 8.6 can corrupt them to U+FFFD.

```tcl
package require mdstack::pdf 0.3

mdstack::pdf::exportFile "input.md" "output.pdf" \
    -title "Documentation" \
    -toc 1 \
    -fontsize 11 \
    -footer "Page %p"
```

---

### `mdstack::pdf::export ast outputFile ?options?`

Exports an AST as PDF.

```tcl
set ast [mdstack::parser::parse $markdown]
mdstack::pdf::export $ast "output.pdf" -title "Documentation" -toc 1
```

---

### `mdstack::pdf::exportModel doc outputFile ?options?`

Exports an mdstack::model document model as PDF.

```tcl
set doc [mdstack::model::new $ast]
mdstack::pdf::exportModel $doc "output.pdf" -title "Documentation"
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
| `-fontdir` | `""` | **ignored** (TTF paths via pdf4tcllib / docir) |
| `-debug` | `0` | **ignored** |
| `-compress` | `1` | **ignored** (pdf4tcl default) |
| `-root` | `""` | **ignored** (image root not wired) |
| `-pdfa` | `""` | PDF/A via `docir::pdf` → pdf4tcl |
| `-userpassword` | `""` | user password (pass-through) |
| `-ownerpassword` | `""` | owner password (pass-through) |
| `-theme` | `""` | `mdstack::theme::toPdfOpts` |
| `-cid` | `0` | full Unicode subset/CID when 1 |

---

### `mdstack::pdf::configure ?options?`

Sets global defaults.

```tcl
mdstack::pdf::configure -fontsize 12 -margin 60
```

---

## Features

### Hyperlinks

Markdown links `[Label](URL)` are clickable PDF annotations (`docir::pdf`).

### PDF/A, encryption, theme (since adapter 0.3)

```tcl
mdstack::pdf::export $ast output.pdf -pdfa 1b
mdstack::pdf::export $ast output.pdf -userpassword "secret"
mdstack::pdf::export $ast output.pdf -theme hell
```

---

## Limitations

- `-fontdir`, `-compress`, `-debug`, `-root` are accepted and ignored
- Raw `html_block` is shown as a code block (no HTML engine in PDF)
- Display math needs pdf4tcllib math; otherwise source `$…$` / `$$…$$`

---

## See also

- [mdhelp_pdf](mdhelp_pdf.md) – widget-based PDF export
- [pdf4tcllib](pdf4tcllib.md) – PDF extension library
- [mdstack::parser](mdparser.md) – Markdown parser
