#!/usr/bin/env tclsh
# test/parser-deflist.tcl
# Tests for Definition Lists

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]
package require mdparser 0.2

set total 0; set passed 0; set failed 0; set skipped 0

proc assert {testName condition} {
    uplevel 1 [list incr total]
    if {[uplevel 1 [list expr $condition]]} {
        uplevel 1 [list incr passed]
    } else {
        uplevel 1 [list incr failed]
        puts "  FAIL: $testName"
    }
}

proc getBlock {ast idx} { lindex [dict get $ast blocks] $idx }
proc getDlItem {block idx} { lindex [dict get $block items] $idx }
proc termText {item} {
    set txt ""
    foreach i [dict get $item term] {
        if {[dict get $i type] eq "text"} { append txt [dict get $i value] }
    }
    return $txt
}
proc defText {item defIdx} {
    set def [lindex [dict get $item definitions] $defIdx]
    set txt ""
    foreach i $def {
        if {[dict get $i type] eq "text"} { append txt [dict get $i value] }
    }
    return $txt
}

# ============================================================
# 1. Simple definition list
# ============================================================

set ast [mdparser::parse {Term Eins
: Definition for term one.}]
set dl [getBlock $ast 0]

assert "dl-simple-type"      {[dict get $dl type] eq "deflist"}
assert "dl-simple-count"     {[llength [dict get $dl items]] == 1}
assert "dl-simple-term"      {[termText [getDlItem $dl 0]] eq "Term Eins"}
assert "dl-simple-def"       {[defText [getDlItem $dl 0] 0] eq "Definition for term one."}

# ============================================================
# 2. Two entries
# ============================================================

set ast [mdparser::parse {API
: Application Programming Interface

CLI
: Command Line Interface}]
set dl [getBlock $ast 0]

assert "dl-two-count"  {[llength [dict get $dl items]] == 2}
assert "dl-two-term1"  {[termText [getDlItem $dl 0]] eq "API"}
assert "dl-two-def1"   {[defText [getDlItem $dl 0] 0] eq "Application Programming Interface"}
assert "dl-two-term2"  {[termText [getDlItem $dl 1]] eq "CLI"}
assert "dl-two-def2"   {[defText [getDlItem $dl 1] 0] eq "Command Line Interface"}

# ============================================================
# 3. Mehrere Definitionen pro Term
# ============================================================

set ast [mdparser::parse {Bank
: Sitzgelegenheit
: Finanzinstitut
: Flussufer}]
set dl [getBlock $ast 0]
set item [getDlItem $dl 0]

assert "dl-multi-def-count" {[llength [dict get $item definitions]] == 3}
assert "dl-multi-def-1"     {[defText $item 0] eq "Sitzgelegenheit"}
assert "dl-multi-def-2"     {[defText $item 1] eq "Finanzinstitut"}
assert "dl-multi-def-3"     {[defText $item 2] eq "Flussufer"}

# ============================================================
# 4. Contiguous without blank lines
# ============================================================

set ast [mdparser::parse {Alpha
: First letter
Beta
: Second letter
Gamma
: Third letter}]
set dl [getBlock $ast 0]

assert "dl-compact-count"  {[llength [dict get $dl items]] == 3}
assert "dl-compact-term1"  {[termText [getDlItem $dl 0]] eq "Alpha"}
assert "dl-compact-term2"  {[termText [getDlItem $dl 1]] eq "Beta"}
assert "dl-compact-term3"  {[termText [getDlItem $dl 2]] eq "Gamma"}

# ============================================================
# 5. Inline formatting in term
# ============================================================

set ast [mdparser::parse {**Bold Term**
: Definition dazu.}]
set dl [getBlock $ast 0]
set item [getDlItem $dl 0]

set hasStrong 0
foreach i [dict get $item term] {
    if {[dict get $i type] eq "strong"} { set hasStrong 1 }
}
assert "dl-inline-term-strong" {$hasStrong == 1}

# ============================================================
# 6. Inline formatting in definition
# ============================================================

set ast [mdparser::parse {Term
: Definition mit **bold** und *italic*.}]
set dl [getBlock $ast 0]
set def [lindex [dict get [getDlItem $dl 0] definitions] 0]

set hasStrong 0
set hasEm 0
foreach i $def {
    if {[dict get $i type] eq "strong"} { set hasStrong 1 }
    if {[dict get $i type] eq "emphasis"} { set hasEm 1 }
}
assert "dl-inline-def-strong" {$hasStrong == 1}
assert "dl-inline-def-em"     {$hasEm == 1}

# ============================================================
# 7. Paragraph vor und nach Deflist
# ============================================================

set ast [mdparser::parse {Paragraph davor.

Hund
: Haustier

Paragraph danach.}]
set blocks [dict get $ast blocks]

assert "dl-context-count" {[llength $blocks] == 3}
assert "dl-context-para1" {[dict get [lindex $blocks 0] type] eq "paragraph"}
assert "dl-context-dl"    {[dict get [lindex $blocks 1] type] eq "deflist"}
assert "dl-context-para2" {[dict get [lindex $blocks 2] type] eq "paragraph"}

# ============================================================
# 8. Kein Deflist – normaler Paragraph
# ============================================================

set ast [mdparser::parse {Normaler Text.
Noch mehr Text.}]

assert "dl-not-dl" {[dict get [getBlock $ast 0] type] eq "paragraph"}

# ============================================================
# 9. Not a deflist – colon in the middle of text
# ============================================================

set ast [mdparser::parse {Hinweis: Das ist kein Deflist.}]

assert "dl-colon-in-text" {[dict get [getBlock $ast 0] type] eq "paragraph"}

# ============================================================
# 10. Blank lines between term and definition
# ============================================================

set ast [mdparser::parse {Hund
: Bester Freund des Menschen

Katze
: Independent companion

Fisch
: Leise und pflegeleicht}]
set dl [getBlock $ast 0]

assert "dl-spaced-count" {[llength [dict get $dl items]] == 3}
assert "dl-spaced-term3" {[termText [getDlItem $dl 2]] eq "Fisch"}
assert "dl-spaced-def3"  {[defText [getDlItem $dl 2] 0] eq "Leise und pflegeleicht"}

# ============================================================
# 11. Code in Definition
# ============================================================

set ast [mdparser::parse {Kommando
: Use `ls -la` for details.}]
set dl [getBlock $ast 0]
set def [lindex [dict get [getDlItem $dl 0] definitions] 0]

set hasCode 0
foreach i $def {
    if {[dict get $i type] eq "inline_code"} { set hasCode 1 }
}
assert "dl-code-in-def" {$hasCode == 1}

# ============================================================
# 12. Link in Definition
# ============================================================

set ast [mdparser::parse {Webseite
: See [Tcl Wiki](https://wiki.tcl-lang.org) for details.}]
set dl [getBlock $ast 0]
set def [lindex [dict get [getDlItem $dl 0] definitions] 0]

set hasLink 0
foreach i $def {
    if {[dict get $i type] eq "link"} { set hasLink 1 }
}
assert "dl-link-in-def" {$hasLink == 1}

# ============================================================
# 13. termText Feld vorhanden
# ============================================================

set ast [mdparser::parse {Mein Term
: Meine Def}]
set item [getDlItem [getBlock $ast 0] 0]

assert "dl-termText-field" {[dict exists $item termText]}
assert "dl-termText-value" {[dict get $item termText] eq "Mein Term"}

# ============================================================
# Result
# ============================================================

puts "[file tail [info script]]:\tTotal\t$total\tPassed\t$passed\tSkipped\t$skipped\tFailed\t$failed"
