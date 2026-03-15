#!/usr/bin/env tclsh
# test-emoji-pdf.tcl
# ============================================================
# Testet Emoji-Darstellung in PDF via mdpdf::exportFile.
#
# exportFile liest die .md Datei binaer und ersetzt Emoji-Bytes
# BEVOR Tcl sie zu U+FFFD zerstoert.
#
# Aufruf:  tclsh test-emoji-pdf.tcl
# Erzeugt: test-emoji.pdf
# ============================================================

set scriptDir [file dirname [file normalize [info script]]]
set libDir [file normalize [file join $scriptDir .. lib]]
set vendorDir [file normalize [file join $scriptDir .. vendors tm]]
tcl::tm::path add $libDir
tcl::tm::path add $vendorDir

package require mdpdf 0.2

set mdFile [file join $scriptDir test-emoji.md]
set outFile [file join $scriptDir test-emoji.pdf]

if {![file exists $mdFile]} {
    puts stderr "FEHLER: $mdFile nicht gefunden"
    exit 1
}

mdpdf::exportFile $mdFile $outFile \
    -title "Emoji/Unicode Test" \
    -header "Emoji-Test - Seite %p" \
    -footer "- %p -" \
    -toc 0 \
    -fontsize 11 \
    -debug 1

puts ""
puts "PDF erzeugt: $outFile"
puts "Bitte oeffnen und Emoji-Fallbacks pruefen."
