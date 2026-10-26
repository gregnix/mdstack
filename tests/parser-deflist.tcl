#!/usr/bin/env tclsh
# test/parser-deflist.tcl
# Tests for Definition Lists

# Eigene Module aus dem Repo (Tests laufen aus dem Repo)
if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}


package require mdstack::parser 0.2

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

set ast [mdstack::parser::parse {Term Eins
: Definition for term one.}]
set dl [getBlock $ast 0]

assert "dl-simple-type"      {[dict get $dl type] eq "deflist"}
assert "dl-simple-count"     {[llength [dict get $dl items]] == 1}
assert "dl-simple-term"      {[termText [getDlItem $dl 0]] eq "Term Eins"}
assert "dl-simple-def"       {[defText [getDlItem $dl 0] 0] eq "Definition for term one."}

# ============================================================
# 2. Two entries
# ============================================================

set ast [mdstack::parser::parse {API
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

set ast [mdstack::parser::parse {Bank
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

set ast [mdstack::parser::parse {Alpha
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

set ast [mdstack::parser::parse {**Bold Term**
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

set ast [mdstack::parser::parse {Term
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

set ast [mdstack::parser::parse {Paragraph davor.

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

set ast [mdstack::parser::parse {Normaler Text.
Noch mehr Text.}]

assert "dl-not-dl" {[dict get [getBlock $ast 0] type] eq "paragraph"}

# ============================================================
# 9. Not a deflist – colon in the middle of text
# ============================================================

set ast [mdstack::parser::parse {Hinweis: Das ist kein Deflist.}]

assert "dl-colon-in-text" {[dict get [getBlock $ast 0] type] eq "paragraph"}

# ============================================================
# 10. Blank lines between term and definition
# ============================================================

set ast [mdstack::parser::parse {Hund
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

set ast [mdstack::parser::parse {Kommando
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

set ast [mdstack::parser::parse {Webseite
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

set ast [mdstack::parser::parse {Mein Term
: Meine Def}]
set item [getDlItem [getBlock $ast 0] 0]

assert "dl-termText-field" {[dict exists $item termText]}
assert "dl-termText-value" {[dict get $item termText] eq "Mein Term"}

# ============================================================
# 14. Mehrzeilige Definition (eingerueckte Folgezeilen)
# ============================================================
#
# Bis 2026-10-19 wurde jede eingerueckte Folgezeile ein eigener Term ohne
# Definition -- gemessen an den Glossaren der bookkit-Buecher.

set ast [mdstack::parser::parse {**AppMain.tcl**
: Startskript in `Contents`. Tk laedt es selbst, wenn
  `wish` ohne Skriptargument startet. Siehe
  [App weitergeben](108-app.md).

**Aqua**
: Natives Fenstersystem.}]
set dl [getBlock $ast 0]
assert "dl-wrap-two-items" {[llength [dict get $dl items]] == 2}
set item [getDlItem $dl 0]
assert "dl-wrap-one-def" {[llength [dict get $item definitions]] == 1}
set hasLink 0
foreach i [lindex [dict get $item definitions] 0] {
    if {[dict get $i type] eq "link"} { set hasLink 1 }
}
assert "dl-wrap-link-in-def" {$hasLink == 1}
assert "dl-wrap-second-term" {[dict get [getDlItem $dl 1] termText] eq "**Aqua**"}

# Gegenprobe: ein nicht eingerueckter Term direkt danach bleibt ein Term.
set ast [mdstack::parser::parse {A
: eins
B
: zwei}]
assert "dl-wrap-unindented-term" {[llength [dict get [getBlock $ast 0] items]] == 2}

# ============================================================
# Leere Definition und Definition ohne Term (2026-10-25)
# Aus den umgewandelten Handbuchseiten (h2md, man2markdown): ":" allein
# und ": text" nach Tabelle, Codeblock oder Absatz wurden als Absatz mit
# woertlichem ": " gedruckt.
# ============================================================

# ":" allein, danach Codeblock: Term ohne Definition, Code bleibt Block
set ast [mdstack::parser::parse "**SYNOPSIS**\n: \n\n```\ncode\n```"]
set dl [getBlock $ast 0]
assert "dl-empty-def-is-deflist" {[dict get $dl type] eq "deflist"}
assert "dl-empty-def-no-defs" {[llength [dict get [getDlItem $dl 0] definitions]] == 0}
assert "dl-empty-def-code-after" {[dict get [getBlock $ast 1] type] eq "code_block"}

# ":" allein, danach Absatz: der Absatz ist die Definition
set ast [mdstack::parser::parse "**-a** x\n: \n\n\nText der Option.\n\n**-b** y\n: B."]
set dl [getBlock $ast 0]
assert "dl-empty-def-para-one-block" {[llength [dict get $ast blocks]] == 1}
assert "dl-empty-def-para-two-items" {[llength [dict get $dl items]] == 2}
assert "dl-empty-def-para-taken" {[dict get [lindex [dict get [getDlItem $dl 0] definitions] 0 0] value] eq "Text der Option."}

# ": text" nach einer Tabelle: Eintrag mit leerem Term, kein ": "
set ast [mdstack::parser::parse "| a | b |\n|---|---|\n| 1 | 2 |\n\n: `-d z`\n\n: `-e w`"]
set dl [getBlock $ast 1]
assert "dl-orphan-is-deflist" {[dict get $dl type] eq "deflist"}
assert "dl-orphan-empty-term" {[dict get [getDlItem $dl 0] termText] eq ""}
assert "dl-orphan-two-defs" {[llength [dict get [getDlItem $dl 0] definitions]] == 2}

# ": text" nach "...lauten:" und danach ein normaler Term
set ast [mdstack::parser::parse "Die Befehle lauten:\n\n: Leerzeile.\n\nab\n: Zeile."]
assert "dl-orphan-after-para" {[dict get [getBlock $ast 1] type] eq "deflist"}
assert "dl-orphan-then-term" {[dict get [getDlItem [getBlock $ast 1] 1] termText] eq "ab"}

# Term, Leerzeile, ":" allein, Leerzeile, Absatz mit eingerueckten
# Folgezeilen (man2markdown, mathfunc "isfinite arg")
set ast [mdstack::parser::parse "**isfinite** *arg*\n\n:   \n\nGibt 1 zurueck,\n    wenn endlich.\n\n**isinf** *arg*\n\n:   \n\nGibt 1 zurueck."]
assert "dl-loose-two-lists" {[llength [dict get $ast blocks]] == 2}
set item [getDlItem [getBlock $ast 0] 0]
assert "dl-loose-term" {[dict get $item termText] eq "**isfinite** *arg*"}
assert "dl-loose-def" {[llength [dict get $item definitions]] == 1}
# Gegenprobe: Absatz, Leerzeile, ": text" -> Absatz bleibt Absatz
set ast [mdstack::parser::parse "Absatz.\n\n: Text."]
assert "dl-loose-only-empty" {[dict get [getBlock $ast 0] type] eq "paragraph"}
# ":" allein ohne Term (nach Codeblock, tklib menubar) wird weggelassen
set ast [mdstack::parser::parse "```\nx\n```\n\n:  \n\n**C**\n: Eintrag."]
assert "dl-lone-colon-dropped" {[llength [dict get $ast blocks]] == 2}
assert "dl-lone-colon-next" {[dict get [getBlock $ast 1] type] eq "deflist"}

# ============================================================
# Result
# ============================================================

puts "[file tail [info script]]:\tTotal\t$total\tPassed\t$passed\tSkipped\t$skipped\tFailed\t$failed"
