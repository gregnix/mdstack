# pdf4tcllib

> **API reference:** [English version](../en/pdf4tcllib.md)
> This German documentation covers concepts and usage scenarios.
> For exact signatures and options refer to the English version.


Erweiterungsbibliothek fuer pdf4tcl.

## Uebersicht

pdf4tcllib schliesst die wichtigsten Luecken in pdf4tcl:
Unicode-Absicherung, Emoji-Fallbacks, Font-Management, Text-Layout
und Tabellen-Rendering. Einzeldatei (~1900 Zeilen), alle 8 Module enthalten.

## Abhaengigkeiten

- pdf4tcl 0.9+ (zwingend)
- Tcl 8.6+ (zwingend)
- Tk (nur fuer image-Modul)
- DejaVu-Fonts (optional, Fallback auf Helvetica)

## Installation

In mdstack liegt pdf4tcllib unter `vendors/tm/`:

```tcl
# Automatisch: mdpdf und mdhelp_pdf fuegen den Pfad selbst hinzu
package require mdpdf 0.2
# pdf4tcllib wird automatisch gefunden

# Manuell: Pfad explizit setzen
tcl::tm::path add /pfad/zu/mdstack-2.0/vendors/tm
package require pdf4tcllib 0.1

# Standalone (ohne mdstack)
tcl::tm::path add /pfad/zu/pdf4tcllib
package require pdf4tcllib 0.1
```

## Module

### fonts -- Font-Management

```tcl
pdf4tcllib::fonts::init ?-fontdir /pfad? ?-family DejaVuSansCondensed?
pdf4tcllib::fonts::fontSans       ;# -> "Pdf4tclSans" oder "Helvetica"
pdf4tcllib::fonts::fontSansBold   ;# -> "Pdf4tclSansBold" oder "Helvetica-Bold"
pdf4tcllib::fonts::fontMono       ;# -> "Courier"
pdf4tcllib::fonts::hasTtf         ;# -> 1/0
pdf4tcllib::fonts::isMonospace $f ;# -> 1/0
pdf4tcllib::fonts::widthFactor $f ;# -> 0.58
```

**fontWidthFactor:** Registrierte Fonts mit empirischen Breitenfaktoren:

| Font | Faktor |
|------|--------|
| Helvetica | 0.52 |
| Helvetica-Bold | 0.56 |
| Helvetica-Oblique | 0.58 |
| Helvetica-BoldOblique | 0.64 |
| Courier | 0.60 |
| DejaVu-Varianten | 0.58 |

### unicode -- Crash-Schutz und Emoji-Fallbacks

**Kernfunktionen:**

```tcl
# Text bereinigen (BMP-Zeichen, Surrogate-Paare, U+FFFD)
set clean [pdf4tcllib::unicode::sanitize $text ?-mono 0?]

# Sicherer Text-Output in PDF
pdf4tcllib::unicode::safeText $pdf $text ?-x 50? ?-y 100?
```

**Emoji-Handling (Byte-Level):**

```tcl
# Rohe UTF-8 Bytes scannen, 4-Byte Emojis durch ASCII ersetzen
# MUSS auf BINARY Data aufgerufen werden, VOR encoding convertfrom!
set clean [pdf4tcllib::unicode::preprocessBytes $rawData]

# Convenience: Datei lesen mit Emoji-Preprocessing
set text [pdf4tcllib::unicode::readFile $filename]
```

**Hintergrund:** Tcl 8.6 kann Codepoints > U+FFFF nicht darstellen
und konvertiert sie zu U+FFFD (Replacement Character). Weder `\U`-Escapes
noch `format %c` funktionieren fuer Emojis. `preprocessBytes` arbeitet
deshalb auf rohen UTF-8 Bytes und erkennt 4-Byte Sequenzen (0xF0...)
bevor Tcl's Encoding sie zerstoert.

**Emoji-Fallback-Tabelle (Auswahl):**

| Emoji | Codepoint | Fallback |
|-------|-----------|----------|
| 😀 | U+1F600 | `:-)`  |
| 😁 | U+1F601 | `:-D`  |
| 😂 | U+1F602 | `:'D`  |
| 😉 | U+1F609 | `;-)`  |
| 😍 | U+1F60D | `<3`   |
| 😎 | U+1F60E | `B-)`  |
| 🤔 | U+1F914 | `(?)`  |
| 🎉 | U+1F389 | `(!)`  |
| 👍 | U+1F44D | `(+1)` |
| 👎 | U+1F44E | `(-1)` |
| 🔥 | U+1F525 | `(*)`  |
| 🚀 | U+1F680 | `[>]`  |
| 🔒 | U+1F512 | `[L]`  |
| 📝 | U+1F4DD | `[doc]`|
| 📁 | U+1F4C1 | `[D]`  |

Zusaetzlich Range-basierte Defaults fuer nicht explizit gemappte Emojis
(z.B. alle Smileys U+1F600-1F64F -> `:-)`).

**BMP-Ersetzungen (sanitize):**

| Zeichen | Unicode | Ersetzung (Base) | Ersetzung (TTF) |
|---------|---------|------------------|-----------------|
| ✅ | U+2705 | `(OK)` | `✓` (U+2713) |
| ❌ | U+274C | `(X)` | `(X)` |
| ⚠ | U+26A0 | `(!)` | `(!)` |
| ❤ | U+2764 | `<3` | `<3` |
| ✨ | U+2728 | `*` | `★` (U+2605) |
| „ | U+201E | `"` | `"` |
| " | U+201C | `"` | `"` |
| ' | U+2018 | `'` | `'` |
| ' | U+2019 | `'` | `'` |

### text -- Text-Layout

```tcl
set w [pdf4tcllib::text::width $text $fontSize $fontName]
set lines [pdf4tcllib::text::wrap $text $maxW $fontSize $fontName ?codeCont?]
set cut [pdf4tcllib::text::truncate $text $maxW $fontSize $fontName]
set exp [pdf4tcllib::text::expandTabs $text ?tabWidth?]
set font [pdf4tcllib::text::detectFont $line]
```

### table -- Tabellen

```tcl
# Listen-Format: {header aligns row1 row2 ...}
# Dict-Format:   {header {..} rows {{..}} aligns {..}}
pdf4tcllib::table::render $pdf $tableData $x yVar $maxW \
    $yTop $yBot pageNoVar $pageW $pageH $margin $fontSize $lineH
```

### page -- Seitenkontext

```tcl
set ctx [pdf4tcllib::page::context a4 ?-margin 25? ?-landscape 0?]
pdf4tcllib::page::lineheight 12
pdf4tcllib::page::header $pdf $ctx "Titel"
pdf4tcllib::page::footer $pdf $ctx "Text" $pageNo
pdf4tcllib::page::number $pdf $ctx 3 10
```

### drawing -- Zeichnen

```tcl
pdf4tcllib::drawing::gradient_v $pdf $x $y $w $h $c1 $c2
pdf4tcllib::drawing::roundedRect $pdf $x $y $w $h $r
pdf4tcllib::drawing::polygon $pdf $cx $cy $radius $sides
pdf4tcllib::drawing::textRotated $pdf $text $x $y $angle $size
```

### units -- Masseinheiten

```tcl
pdf4tcllib::units::mm 25     ;# -> 70.87 pt
pdf4tcllib::units::cm 2.5    ;# -> 70.87 pt
pdf4tcllib::units::inch 1    ;# -> 72.0 pt
pdf4tcllib::units::to_mm 72  ;# -> 25.4 mm
```

### image -- Bilder (benoetigt Tk)

```tcl
pdf4tcllib::image::insert $pdf $tkImg $x yVar $maxW ...
pdf4tcllib::image::insertAt $pdf $tkImg $xPos yVar $maxW ...
```

## Wichtig: Baseline-Positionierung

In pdf4tcl mit `-orient true` ist die Y-Position die Baseline,
nicht die Oberkante. Erste Textzeile in einer Box bei `boxY + fontSize`.

## Emoji-Workflow

Empfohlener Ablauf fuer Markdown-Dateien mit Emojis:

```tcl
# Option A: mdpdf::exportFile (empfohlen)
package require mdpdf 0.2
mdpdf::exportFile "input.md" "output.pdf" -title "Test"

# Option B: Manuell
package require pdf4tcllib 0.1
set text [pdf4tcllib::unicode::readFile "input.md"]
# ... weiterverarbeiten ...

# Option C: Ganz manuell
set f [open "input.md" rb]
set raw [read $f]; close $f
set clean [pdf4tcllib::unicode::preprocessBytes $raw]
set text [encoding convertfrom utf-8 $clean]
```
