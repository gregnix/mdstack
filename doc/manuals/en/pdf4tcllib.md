# pdf4tcllib

## Purpose

`pdf4tcllib` fills the most important gaps in pdf4tcl: Unicode safety,
Emoji fallbacks, font management, text layout, and table rendering.
Single file (~1900 lines), all 8 modules included.

---

## Dependencies

- pdf4tcl 0.9+ (required)
- Tcl 8.6+ (required)
- Tk (image module only)
- DejaVu fonts (optional, falls back to Helvetica)

---

## Installation

In mdstack, pdf4tcllib is located under `vendors/tm/`:

```tcl
# Automatic: mdpdf and mdhelp_pdf add the path themselves
package require mdpdf 0.2

# Manual
tcl::tm::path add /path/to/mdstack/vendors/tm
package require pdf4tcllib 0.1
```

---

## Modules

### fonts — Font management

```tcl
pdf4tcllib::fonts::init ?-fontdir /path? ?-family DejaVuSansCondensed?
pdf4tcllib::fonts::fontSans       ;# "Pdf4tclSans" or "Helvetica"
pdf4tcllib::fonts::fontSansBold   ;# "Pdf4tclSansBold" or "Helvetica-Bold"
pdf4tcllib::fonts::fontMono       ;# "Courier"
pdf4tcllib::fonts::hasTtf         ;# 1/0
pdf4tcllib::fonts::isMonospace $f ;# 1/0
pdf4tcllib::fonts::widthFactor $f ;# 0.58
```

Width factors (empirical):

| Font | Factor |
|------|--------|
| Helvetica | 0.52 |
| Helvetica-Bold | 0.56 |
| Helvetica-Oblique | 0.58 |
| Helvetica-BoldOblique | 0.64 |
| Courier | 0.60 |
| DejaVu variants | 0.58 |

---

### unicode — Crash protection and Emoji fallbacks

```tcl
# Clean text (BMP chars, surrogate pairs, U+FFFD)
set clean [pdf4tcllib::unicode::sanitize $text ?-mono 0?]

# Safe text output in PDF
pdf4tcllib::unicode::safeText $pdf $text ?-x 50? ?-y 100?

# Scan raw UTF-8 bytes, replace 4-byte Emojis with ASCII
# MUST be called on BINARY data, BEFORE encoding convertfrom!
set clean [pdf4tcllib::unicode::preprocessBytes $rawData]

# Convenience: read file with Emoji preprocessing
set text [pdf4tcllib::unicode::readFile $filename]
```

**Background:** Tcl 8.6 cannot represent codepoints > U+FFFF and
converts them to U+FFFD. `preprocessBytes` works on raw UTF-8 bytes
and detects 4-byte sequences (0xF0...) before Tcl's encoding destroys them.

Emoji fallback table (selection):

| Emoji | Codepoint | Fallback |
|-------|-----------|----------|
| 😀 | U+1F600 | `:-)`  |
| 😂 | U+1F602 | `:'D`  |
| 😎 | U+1F60E | `B-)`  |
| 🎉 | U+1F389 | `(!)`  |
| 👍 | U+1F44D | `(+1)` |
| 🔥 | U+1F525 | `(*)`  |
| 🚀 | U+1F680 | `[>]`  |
| 📝 | U+1F4DD | `[doc]`|

---

### text — Text layout

```tcl
set w     [pdf4tcllib::text::width $text $fontSize $fontName]
set lines [pdf4tcllib::text::wrap $text $maxW $fontSize $fontName]
set cut   [pdf4tcllib::text::truncate $text $maxW $fontSize $fontName]
set exp   [pdf4tcllib::text::expandTabs $text ?tabWidth?]
set font  [pdf4tcllib::text::detectFont $line]
```

---

### table — Tables

```tcl
pdf4tcllib::table::render $pdf $tableData $x yVar $maxW \
    $yTop $yBot pageNoVar $pageW $pageH $margin $fontSize $lineH
```

---

### page — Page context

```tcl
set ctx [pdf4tcllib::page::context a4 ?-margin 25? ?-landscape 0?]
pdf4tcllib::page::lineheight 12
pdf4tcllib::page::header $pdf $ctx "Title"
pdf4tcllib::page::footer $pdf $ctx "Text" $pageNo
```

---

### drawing — Drawing primitives

```tcl
pdf4tcllib::drawing::gradient_v   $pdf $x $y $w $h $c1 $c2
pdf4tcllib::drawing::roundedRect  $pdf $x $y $w $h $r
pdf4tcllib::drawing::polygon      $pdf $cx $cy $radius $sides
pdf4tcllib::drawing::textRotated  $pdf $text $x $y $angle $size
```

---

### units — Unit conversion

```tcl
pdf4tcllib::units::mm 25     ;# -> 70.87 pt
pdf4tcllib::units::cm 2.5    ;# -> 70.87 pt
pdf4tcllib::units::inch 1    ;# -> 72.0 pt
pdf4tcllib::units::to_mm 72  ;# -> 25.4 mm
```

---

### image — Images (requires Tk)

```tcl
pdf4tcllib::image::insert   $pdf $tkImg $x yVar $maxW ...
pdf4tcllib::image::insertAt $pdf $tkImg $xPos yVar $maxW ...
```

---

## Important: baseline positioning

In pdf4tcl with `-orient true`, the Y coordinate is the **baseline**,
not the top edge. First text line in a box: `boxY + fontSize`.

---

## Emoji workflow

```tcl
# Option A: mdpdf::exportFile (recommended)
mdpdf::exportFile "input.md" "output.pdf" -title "Test"

# Option B: read file manually
set text [pdf4tcllib::unicode::readFile "input.md"]

# Option C: full manual
set f [open "input.md" rb]
set raw [read $f]; close $f
set clean [pdf4tcllib::unicode::preprocessBytes $raw]
set text [encoding convertfrom utf-8 $clean]
```
