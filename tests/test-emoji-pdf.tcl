#!/usr/bin/env tclsh
# test-emoji-pdf.tcl
# ============================================================
# Testet Emoji-Darstellung in PDF via mdstack::pdf::exportFile.
#
# exportFile liest die .md Datei binaer und ersetzt Emoji-Bytes
# BEVOR Tcl sie zu U+FFFD zerstoert.
#
# Aufruf:  tclsh test-emoji-pdf.tcl
# Erzeugt: test-emoji.pdf
# ============================================================

set scriptDir [file dirname [file normalize [info script]]]
source [file join $scriptDir _paths.tcl]

# Self-skip ohne pdf4tcl (das Modul mdstack::pdf braucht es)
if {[catch {package require mdstack::pdf 0.2}]} {
    puts "SKIP test-emoji-pdf.tcl: pdf4tcl/mdstack::pdf not available"
    exit 0
}

set mdFile [file join $scriptDir test-emoji.md]
set outFile [file join $scriptDir test-emoji.pdf]

if {![file exists $mdFile]} {
    puts stderr "FEHLER: $mdFile nicht gefunden"
    exit 1
}

mdstack::pdf::exportFile $mdFile $outFile \
    -title "Emoji/Unicode Test" \
    -header "Emoji-Test - Seite %p" \
    -footer "- %p -" \
    -toc 0 \
    -fontsize 11 \
    -debug 1

puts ""
puts "PDF erzeugt: $outFile"
puts "Bitte oeffnen und Emoji-Fallbacks pruefen."
