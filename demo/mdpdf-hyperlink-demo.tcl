#!/usr/bin/env tclsh
# mdpdf-hyperlink-demo.tcl
# Zeigt klickbare Hyperlinks im PDF-Export aus Markdown.
# pdf4tcl 0.9.4.11 + mdpdf 0.2
#
# Links aus Markdown [Label](URL) werden als klickbare
# PDF-Annotationen eingebettet (hyperlinkAdd).

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]
package require mdpdf 0.2

set scriptDir [file dirname [file normalize [info script]]]
set pdfDir    [file join $scriptDir pdf]
file mkdir $pdfDir

set markdown {
# Clickable Hyperlinks Demo

All links in this PDF are clickable in a PDF viewer.

## Simple Links

A simple link: [Tcl/Tk Homepage](https://www.tcl.tk)

Link with longer label: [Tcl Developer Xchange -- the official Tcl/Tk website](https://www.tcl.tk)

## Multiple Links in One Paragraph

Visit [GitHub](https://github.com/gregnix/pdf4tcl) or
[SourceForge](https://sourceforge.net/projects/pdf4tcl/) for the
source code. Documentation is available on the
[Wiki](https://wiki.tcl-lang.org).

## Links in Lists

- [pdf4tcl on GitHub](https://github.com/gregnix/pdf4tcl)
- [TIP 700 -- Markdown for Tcl/Tk man pages](https://core.tcl-lang.org/tips/doc/trunk/tip/700.md)
- [veraPDF Validator](https://verapdf.org)
- [Tcl/Tk Documentation](https://www.tcl.tk/doc/)

## Links in Tables

| Project | Link | Description |
|---------|------|-------------|
| pdf4tcl | [GitHub](https://github.com/gregnix/pdf4tcl) | PDF library for Tcl |
| mdstack | [GitHub](https://github.com/gregnix) | Markdown tools |
| veraPDF | [verapdf.org](https://verapdf.org) | PDF/A validator |

## Mixed Content

The **pdf4tcl** library (version [0.9.4.11](https://github.com/gregnix/pdf4tcl))
supports AES-128 encryption, PDF/A-1b/2b, and clickable hyperlinks.

---

*Links are clickable in Adobe Reader, Evince, Okular, and most PDF viewers.*
}

package require mdparser 0.2
set ast [mdparser::parse $markdown]

set out [file join $pdfDir mdpdf-hyperlinks.pdf]
mdpdf::export $ast $out \
    -title    "Hyperlinks Demo" \
    -header   "Clickable Hyperlinks -- Page %p" \
    -footer   "- %p -" \
    -fontsize 11 \
    -margin   50
puts "Written: $out"
puts "Open in a PDF viewer and click the links."
