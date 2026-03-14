#!/usr/bin/env tclsh
# mdpdf-themes-demo.tcl
# Demonstriert mdpdf mit verschiedenen mdtheme-Themes.
# Erzeugt eine PDF-Datei pro Theme: hell, dunkel, solarized.
#
# Requires: mdparser 0.2, mdtheme 0.1, mdpdf 0.2
#
# Aktueller Stand (mdpdf 0.2):
#   - fontsize und margin werden aus dem Theme uebernommen
#   - Farben (colorLink, colorCode, colorHeading) haben noch
#     keine Auswirkung -- folgt mit pdf4tcl 0.9.4.12
#
# Ab pdf4tcl 0.9.4.12:
#   - colorLink  -> Hyperlink-Farbe
#   - colorCode  -> Code-Block-Hintergrund
#   - colorHeading -> Ueberschriften-Farbe

set scriptDir [file dirname [file normalize [info script]]]
tcl::tm::path add [file normalize [file join $scriptDir .. lib]]

package require mdparser 0.2
package require mdtheme  0.1
package require mdpdf    0.2

set outdir [file join $scriptDir pdf]
file mkdir $outdir

set markdown {
# mdpdf Theme Demo

Demonstrates **mdpdf** with different **mdtheme** themes.

## Text Formatting

**Bold**, *italic*, ***bold italic***, ~~strikethrough~~.

`Inline code` with monospace font.

A paragraph with a [clickable link](https://www.tcl.tk) and
another [link to GitHub](https://github.com/gregnix/pdf4tcl).

## Blockquote

> This is a blockquote demonstrating
> the current theme settings.

## Code Block

```tcl
package require mdpdf   0.2
package require mdtheme 0.1

mdpdf::export $ast output.pdf -theme hell
mdpdf::export $ast output.pdf -theme dunkel
```

## Table

| Feature    | hell | dunkel | solarized |
|------------|:----:|:------:|:---------:|
| fontsize   | 11pt | 11pt   | 11pt      |
| margin     | 50pt | 50pt   | 50pt      |
| colorLink  | yes  | yes    | yes       |

## Lists

- Item one
- **Item two** with bold text
- Item with [link](https://tcl.tk)

1. First numbered item
2. Second numbered item

## Definition List

mdtheme
: Shared theme system for HTML, PDF and Tk renderers.

mdpdf
: Markdown to PDF renderer using pdf4tcl as backend.

---

*Generated with mdpdf 0.2 + mdtheme 0.1*
}

set ast [mdparser::parse $markdown]

foreach theme [mdtheme::names] {
    set outfile [file join $outdir "mdpdf-theme-${theme}.pdf"]
    mdpdf::export $ast $outfile \
        -title  "mdpdf -- Theme: $theme" \
        -theme  $theme \
        -toc    1 \
        -header "Theme: $theme -- Page %p" \
        -footer "- %p -"
    puts "Written: $outfile  (theme: $theme)"
}

puts "\nDone."
