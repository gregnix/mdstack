#!/usr/bin/env tclsh
# mdpdf-pdfa-demo.tcl
# Exportiert Markdown als PDF/A-1b direkt (ohne Ghostscript).
# pdf4tcl 0.9.4.11 + mdpdf 0.2
#
# Hinweis: Fuer vollstaendige PDF/A-Konformitaet CIDFonts verwenden
# (Standard-Fonts wie Helvetica sind nicht eingebettet).

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]
package require mdpdf 0.2

set scriptDir [file dirname [file normalize [info script]]]
set pdfDir    [file join $scriptDir pdf]
file mkdir $pdfDir

set markdown {
# PDF/A-1b Demo

This document is exported as PDF/A-1b for long-term archiving.

## What is PDF/A?

PDF/A is an ISO standard for long-term archiving of electronic documents.
It ensures that the document can be rendered identically in the future.

## PDF/A-1b Requirements

- All fonts embedded
- XMP metadata stream
- OutputIntent with ICC color profile
- No encryption
- No transparency (PDF/A-1)

## Links

- [PDF/A on Wikipedia](https://en.wikipedia.org/wiki/PDF/A)
- [veraPDF Validator](https://verapdf.org)
- [pdf4tcl on GitHub](https://github.com/gregnix/pdf4tcl)

## Validation

Validate this file with veraPDF:

```bash
verapdf --flavour 1b mdpdf-pdfa-1b.pdf
```

---

*Created with mdpdf 0.2 / pdf4tcl 0.9.4.11*
}

package require mdparser 0.2
set ast [mdparser::parse $markdown]

# --- PDF/A-1b ---
set out [file join $pdfDir mdpdf-pdfa-1b.pdf]
mdpdf::export $ast $out \
    -title    "PDF/A-1b Demo" \
    -pdfa     1b \
    -fontsize 11 \
    -margin   50
puts "Written: $out"
puts "Validate: verapdf --flavour 1b $out"

# --- PDF/A-2b ---
set out [file join $pdfDir mdpdf-pdfa-2b.pdf]
mdpdf::export $ast $out \
    -title    "PDF/A-2b Demo" \
    -pdfa     2b \
    -fontsize 11 \
    -margin   50
puts "Written: $out"
puts "Validate: verapdf --flavour 2b $out"
