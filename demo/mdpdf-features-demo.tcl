#!/usr/bin/env tclsh
# Demo fuer mdpdf Features:
# - Tables, Blockquotes, Code-Bloecke (Backtick + Tilde)
# - Listen (ul, ol, task), Definition Lists
# - Footnotes, Horizontale Linien, YAML Frontmatter
# - TrueType-Fonts, Header/Footer, Inhaltsverzeichnis
# - Klickbare Hyperlinks (pdf4tcl 0.9.4.11)
# - PDF/A und Verschluesselung als Export-Varianten

# Tcl Module Pfad setzen (lib/ relativ zu demo/)
tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require mdpdf 0.2

set scriptDir [file dirname [file normalize [info script]]]
set mdFile    [file join $scriptDir mdpdf-features-demo.md]
set pdfDir    [file join $scriptDir pdf]
if {![file exists $pdfDir]} { file mkdir $pdfDir }

# --- 1. Standard-Export ---
set outFile [file join $pdfDir mdpdf-features-demo.pdf]
mdpdf::exportFile $mdFile $outFile \
    -title   "mdpdf Features Demo" \
    -header  "mdpdf 0.2 / pdf4tcl 0.9.4.11 -- Page %p" \
    -footer  "- %p -" \
    -toc     1 \
    -fontsize 11 \
    -margin  50
puts "Written: $outFile"

# --- 2. PDF/A-1b Export ---
set outPdfa [file join $pdfDir mdpdf-features-demo-pdfa.pdf]
mdpdf::exportFile $mdFile $outPdfa \
    -title   "mdpdf Features Demo (PDF/A-1b)" \
    -header  "PDF/A-1b -- Page %p" \
    -footer  "- %p -" \
    -toc     1 \
    -fontsize 11 \
    -margin  50 \
    -pdfa    1b
puts "Written: $outPdfa"

# --- 3. Verschluesselter Export ---
set outEnc [file join $pdfDir mdpdf-features-demo-encrypted.pdf]
mdpdf::exportFile $mdFile $outEnc \
    -title         "mdpdf Features Demo (Encrypted)" \
    -header        "Protected -- Page %p" \
    -footer        "- %p -" \
    -fontsize      11 \
    -margin        50 \
    -userpassword  "demo" \
    -ownerpassword "admin"
puts "Written: $outEnc  (user password: demo)"
puts ""
puts "Done. PDFs in: $pdfDir"

# --- 4. Theme-Export (hell / dunkel / solarized) ---
package require mdtheme 0.1

set md2 {# mdpdf Theme Demo

Demonstrates **mdpdf** with different **mdtheme** themes.

## Text Formatting

**Bold**, *italic*, `code`, ~~strikethrough~~.

A paragraph with a [clickable link](https://www.tcl.tk).

## Blockquote

> This is a blockquote with the current theme settings.

## Code Block

```tcl
mdpdf::export $ast output.pdf -theme hell
mdpdf::export $ast output.pdf -theme dunkel
```

## Table

| Feature   | hell | dunkel | solarized |
|-----------|:----:|:------:|:---------:|
| fontsize  | 11pt | 11pt   | 11pt      |
| colorLink | yes  | yes    | yes       |
}

set ast2 [mdparser::parse $md2]
foreach theme [mdtheme::names] {
    set outTheme [file join $pdfDir "mdpdf-theme-${theme}.pdf"]
    mdpdf::export $ast2 $outTheme \
        -title  "mdpdf -- Theme: $theme" \
        -theme  $theme \
        -toc    1 \
        -header "Theme: $theme -- Page %p" \
        -footer "- %p -"
    puts "Written: $outTheme  (theme: $theme)"
}
puts ""
puts "All done. PDFs in: $pdfDir"
