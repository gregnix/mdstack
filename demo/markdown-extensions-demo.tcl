#!/usr/bin/env tclsh
# markdown-extensions-demo.tcl
#
# Demo der mdstack v0.2.10 + docir 2026-05-16 Neuerungen:
# - Setext-Headings
# - Inline + Block Math ($...$, $$...$$)
# - Mermaid in HTML-Sink
# - docir::txt (Plain-Text-Senke)
#
# Aufruf:
#   tclsh markdown-extensions-demo.tcl ?--all|--txt|--md|--html?
#
# Default: alle drei Outputs nacheinander auf stdout.
#
# Vorbedingung:
#   ../lib/mdstack/*.tm  und  ../../docir/lib/tm/docir/*.tm  vorhanden

set scriptDir [file dirname [file normalize [info script]]]
set demoMd [file join $scriptDir extended-markdown.md]

if {![file exists $demoMd]} {
    puts stderr "ERROR: $demoMd not found"
    exit 2
}

# Module-Pfade
::tcl::tm::path add [file join $scriptDir .. lib]
# docir suchen: sibling-Repo oder gleiches Parent
set docirCandidates [list \
    [file normalize [file join $scriptDir .. .. docir lib tm]] \
    [file normalize [file join $scriptDir .. .. .. docir lib tm]] \
    [file normalize [file join $::env(HOME) lib tcltk docir lib tm]]]
foreach p $docirCandidates {
    if {[file isdirectory $p]} {
        ::tcl::tm::path add $p
        break
    }
}

if {[catch {
    package require mdstack::parser
    package require docir
    package require docir::mdSource
} err]} {
    puts stderr "ERROR loading mdstack/docir core: $err"
    exit 2
}

# Mode
set mode "all"
if {$argc >= 1} {
    set mode [lindex $argv 0]
    set mode [string trimleft $mode "-"]
}

# Markdown einlesen + parsen
set fh [open $demoMd r]
fconfigure $fh -encoding utf-8
set md [read $fh]
close $fh

set ast [mdstack::parser::parse $md]
set ir  [docir::md::fromAst $ast]

# Statistiken über das geparste AST
proc countNodes {ast typeName} {
    set count 0
    foreach b [dict get $ast blocks] {
        if {[dict get $b type] eq $typeName} { incr count }
        # Inline math innerhalb von Paragraphs
        if {$typeName eq "math_inline" && [dict get $b type] eq "paragraph"} {
            foreach i [dict get $b content] {
                if {[dict exists $i type] && [dict get $i type] eq "math"} {
                    incr count
                }
            }
        }
    }
    return $count
}

puts "=============================================="
puts "Markdown Extensions Demo -- Statistik"
puts "=============================================="
puts ""
puts "Quelle:  [file tail $demoMd]"
puts "Bloecke: [llength [dict get $ast blocks]]"
puts "  Headings:      [countNodes $ast heading]"
puts "  Paragraphs:    [countNodes $ast paragraph]"
puts "  Math-Blocks:   [countNodes $ast math_block]"
puts "  Math-Inline:   [countNodes $ast math_inline]"
puts "  Code-Blocks:   [countNodes $ast code_block]"
puts "  Lists:         [countNodes $ast list]"
puts "  Tables:        [countNodes $ast table]"
puts "  Divs:          [countNodes $ast div]"
puts "  HRs:           [countNodes $ast hr]"
puts ""

# Output je nach Mode
switch $mode {
    txt {
        package require docir::txt
        puts "================== TXT OUTPUT =================="
        puts [docir::txt::render $ir]
    }
    md {
        package require docir::md
        puts "================== MD ROUNDTRIP =================="
        puts [docir::md::render $ir]
    }
    html {
        package require docir::html
        puts "================== HTML OUTPUT =================="
        puts [docir::html::render $ir [dict create \
            title "Markdown Extensions Demo" \
            includeToc 1 \
            enableMermaid 1 \
            enableMath 1]]
    }
    all - default {
        package require docir::txt
        package require docir::md
        package require docir::html

        puts "================== TXT (excerpt) =================="
        set txt [docir::txt::render $ir]
        # Erste 40 Zeilen zeigen
        set lines [split $txt "\n"]
        puts [join [lrange $lines 0 39] "\n"]
        if {[llength $lines] > 40} {
            puts "... ([expr {[llength $lines] - 40}] more lines)"
        }
        puts ""

        puts "================== MD ROUNDTRIP (excerpt) =================="
        set roundtrip [docir::md::render $ir]
        set rlines [split $roundtrip "\n"]
        puts [join [lrange $rlines 0 39] "\n"]
        if {[llength $rlines] > 40} {
            puts "... ([expr {[llength $rlines] - 40}] more lines)"
        }
        puts ""

        puts "================== HTML head + body excerpt =================="
        set html [docir::html::render $ir [dict create \
            title "Demo" includeToc 1 enableMermaid 1 enableMath 1]]
        # Math + Mermaid + Setext-Headings im HTML zeigen
        foreach line [split $html "\n"] {
            if {[string match "*mermaid*" $line] \
                    || [string match "*katex*" $line] \
                    || [string match {*math display*} $line] \
                    || [string match {*math inline*} $line] \
                    || [string match {*<h1*} $line] \
                    || [string match {*<h2*} $line]} {
                puts "  $line"
            }
        }
        puts ""
        puts "(Vollausgabe via:  tclsh $argv0 --html > demo.html)"

        puts ""
        puts "=============================================="
        puts "  TIPP: 'tclsh $argv0 --html > demo.html'"
        puts "  oeffnet im Browser zeigt Mermaid+Math live."
        puts "=============================================="
    }
}
