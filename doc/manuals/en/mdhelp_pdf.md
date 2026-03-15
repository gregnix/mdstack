# mdhelp_pdf

## Purpose

`mdhelp_pdf` exports the content of a rendered Tk text widget as PDF.
Unlike `mdpdf` (AST-based), it works with the rendered widget content —
capturing frame tables, embedded images, and heading formatting from the viewer.

Version 0.3 delegates PDF generation to pdf4tcllib.

---

## Dependencies

- pdf4tcl (PDF base)
- pdf4tcllib 0.1 (fonts, Unicode, text, tables)
- Tk (for widget access)

---

## Public API

### `mdhelp_pdf::available`

Returns 1 if pdf4tcl is available.

### `mdhelp_pdf::exportFromWidget textWidget outFile ?options?`

Exports the content of a text widget as PDF.

```tcl
set pages [mdhelp_pdf::exportFromWidget .viewer.text "output.pdf" \
    -title    "Manual" \
    -fontsize 11]

puts "$pages pages written"
```

| Option | Default | Description |
|--------|---------|-------------|
| `-title` | `""` | Title on first page |
| `-pagesize` | `A4` | Page size (A4, Letter) |
| `-landscape` | `0` | Landscape mode |
| `-margin` | `50` | Margin in points |
| `-fontsize` | `11` | Base font size |
| `-fontdir` | `""` | Directory with TTF files |
| `-debug` | `0` | Debug output |

### `mdhelp_pdf::exportFromFile mdFile outFile ?options?`

Exports a Markdown file directly as PDF. Same options as `exportFromWidget`.

```tcl
set pages [mdhelp_pdf::exportFromFile "README.md" "output.pdf" \
    -title "Documentation"]
```

---

## Migration from 0.2

The API is unchanged. Internally, 14 functions are replaced by
pdf4tcllib calls (1513 → 627 lines).
