#!/usr/bin/env tclsh
# parser-tip700.tcl -- Tests fuer TIP-700-Features
# Bracketed Spans [text]{.class} und Shortcut Reference Links [text]

set dir [file dirname [file normalize [info script]]]
tcl::tm::path add [file join $dir .. lib]

package require mdparser 0.2

set total 0; set passed 0; set failed 0

proc assert {testName condition} {
    uplevel 1 [list incr total]
    if {[uplevel 1 [list expr $condition]]} {
        uplevel 1 [list incr passed]
    } else {
        uplevel 1 [list incr failed]
        puts "  FAIL: $testName"
    }
}

# =========================================================================
# Helper
# =========================================================================

proc getInlines {md} {
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    return [dict get $block content]
}

proc firstInline {md} {
    lindex [getInlines $md] 0
}

proc spanClass {node} {
    dict get $node class
}

proc spanText {node} {
    set result ""
    foreach i [dict get $node content] {
        if {[dict get $i type] eq "text"} {
            append result [dict get $i value]
        }
    }
    return $result
}

# =========================================================================
# A: Simple bracketed spans
# =========================================================================

set node [firstInline {[array]{.cmd}}]
assert "A1: span type" {[dict get $node type] eq "span"}
assert "A2: span class .cmd" {[spanClass $node] eq "cmd"}
assert "A3: span text" {[spanText $node] eq "array"}

set node [firstInline {[option]{.arg}}]
assert "A4: span class .arg" {[spanClass $node] eq "arg"}

set node [firstInline {[get]{.sub}}]
assert "A5: span class .sub" {[spanClass $node] eq "sub"}

set node [firstInline {[-nonewline]{.optlit}}]
assert "A6: span class .optlit" {[spanClass $node] eq "optlit"}

set node [firstInline {[Tcl_AllowExceptions]{.ccmd}}]
assert "A7: span class .ccmd (C API)" {[spanClass $node] eq "ccmd"}
assert "A8: C API text" {[spanText $node] eq "Tcl_AllowExceptions"}

# =========================================================================
# B: Mehrere Spans hintereinander
# =========================================================================

set inlines [getInlines {[array]{.cmd} [option]{.arg} [arrayName]{.arg}}]
assert "B1: 3 spans + 2 text separators" {[llength $inlines] == 5}
assert "B2: first is span" {[dict get [lindex $inlines 0] type] eq "span"}
assert "B3: first class" {[spanClass [lindex $inlines 0]] eq "cmd"}
assert "B4: second is span" {[dict get [lindex $inlines 2] type] eq "span"}
assert "B5: second class" {[spanClass [lindex $inlines 2]] eq "arg"}
assert "B6: third is span" {[dict get [lindex $inlines 4] type] eq "span"}
assert "B7: third class" {[spanClass [lindex $inlines 4]] eq "arg"}

# =========================================================================
# C: Nested spans
# =========================================================================

set inlines [getInlines {[[-code]{.lit} [code]{.arg}]{.optarg}}]
set outer [lindex $inlines 0]
assert "C1: outer is span" {[dict get $outer type] eq "span"}
assert "C2: outer class" {[spanClass $outer] eq "optarg"}
set innerContent [dict get $outer content]
# Inner: span(.lit), text(" "), span(.arg)
set s1 [lindex $innerContent 0]
set s2 [lindex $innerContent 2]
assert "C3: inner span 1" {[dict get $s1 type] eq "span"}
assert "C4: inner class .lit" {[spanClass $s1] eq "lit"}
assert "C5: inner text -code" {[spanText $s1] eq "-code"}
assert "C6: inner span 2" {[dict get $s2 type] eq "span"}
assert "C7: inner class .arg" {[spanClass $s2] eq "arg"}
assert "C8: inner text code" {[spanText $s2] eq "code"}

# =========================================================================
# D: Spans with inline formatting in content
# =========================================================================

set node [firstInline {[**bold** text]{.note}}]
assert "D1: span with bold" {[dict get $node type] eq "span"}
assert "D2: span class" {[spanClass $node] eq "note"}
set inner [dict get $node content]
assert "D3: bold inside span" {[dict get [lindex $inner 0] type] eq "strong"}

# =========================================================================
# E: Spans nicht verwechselt mit Links
# =========================================================================

set inlines [getInlines {[click here](https://example.com)}]
assert "E1: link not span" {[dict get [lindex $inlines 0] type] eq "link"}

set inlines [getInlines {[click here][ref]}]
# Without reflink definition, falls through - not a span because no {.class}
assert "E2: reflink not span" {[dict get [lindex $inlines 0] type] ne "span"}

# Bare brackets without {.class} remain text
set inlines [getInlines {[just brackets]}]
assert "E3: bare brackets = text" {[dict get [lindex $inlines 0] type] eq "text"}

# =========================================================================
# F: Shortcut Reference Links
# =========================================================================

set md {See the [encoding] command.

[encoding]: encoding.md
}

set ast [mdparser::parse $md]
set para [lindex [dict get $ast blocks] 0]
set inlines [dict get $para content]

# Find the link node
set linkNode ""
foreach i $inlines {
    if {[dict get $i type] eq "link"} { set linkNode $i; break }
}
assert "F1: shortcut ref found" {$linkNode ne ""}
assert "F2: shortcut ref url" {[dict get $linkNode url] eq "encoding.md"}

# Label is inline[]
set labelInlines [dict get $linkNode label]
assert "F3: shortcut ref label" {[dict get [lindex $labelInlines 0] value] eq "encoding"}

# =========================================================================
# G: Shortcut Reference mit Title
# =========================================================================

set md {Use [lsort] for sorting.

[lsort]: lsort.md "List Sort Command"
}

set ast [mdparser::parse $md]
set para [lindex [dict get $ast blocks] 0]
set inlines [dict get $para content]
set linkNode ""
foreach i $inlines {
    if {[dict get $i type] eq "link"} { set linkNode $i; break }
}
assert "G1: shortcut ref with title" {$linkNode ne ""}
assert "G2: url" {[dict get $linkNode url] eq "lsort.md"}
assert "G3: title preserved" {[dict get $linkNode title] eq "List Sort Command"}

# =========================================================================
# H: Shortcut Reference -- kein Match ohne Definition
# =========================================================================

set md {The [unknown] command is not defined as reflink.}
set ast [mdparser::parse $md]
set para [lindex [dict get $ast blocks] 0]
set inlines [dict get $para content]

set hasLink 0
foreach i $inlines {
    if {[dict get $i type] eq "link"} { set hasLink 1 }
}
assert "H1: no link for undefined shortcut ref" {$hasLink == 0}

# =========================================================================
# I: TIP-700-typische Kommandosyntax
# =========================================================================

set md {[puts]{.cmd} [channel]{.optarg} [string]{.arg}}
set inlines [getInlines $md]
set spans {}
foreach i $inlines {
    if {[dict get $i type] eq "span"} { lappend spans $i }
}
assert "I1: three spans in command syntax" {[llength $spans] == 3}
assert "I2: cmd" {[spanClass [lindex $spans 0]] eq "cmd"}
assert "I3: optarg" {[spanClass [lindex $spans 1]] eq "optarg"}
assert "I4: arg" {[spanClass [lindex $spans 2]] eq "arg"}

# =========================================================================
# J: Klassen-Namen Varianten
# =========================================================================

set node [firstInline {[x]{.my-class}}]
assert "J1: hyphenated class name" {[spanClass $node] eq "my-class"}

set node [firstInline {[x]{.cls_2}}]
assert "J2: underscore+digit class" {[spanClass $node] eq "cls_2"}

# =========================================================================
# K: Shortcut Ref neben normalem Link
# =========================================================================

set md {Both [encoding] and [binary scan][binary] work.

[encoding]: encoding.md
[binary]: binary.md
}
set ast [mdparser::parse $md]
set para [lindex [dict get $ast blocks] 0]
set inlines [dict get $para content]
set links {}
foreach i $inlines {
    if {[dict get $i type] eq "link"} { lappend links $i }
}
assert "K1: two links" {[llength $links] == 2}
assert "K2: shortcut ref url" {[dict get [lindex $links 0] url] eq "encoding.md"}
assert "K3: regular ref url" {[dict get [lindex $links 1] url] eq "binary.md"}

# =========================================================================
puts ""
puts "=== parser-tip700.tcl ==="
puts "$passed/$total passed, $failed failed"
