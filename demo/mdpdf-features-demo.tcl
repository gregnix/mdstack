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
