#!/usr/bin/env tclsh
# parser-tip700.tcl -- Tests fuer TIP-700-Features
# Bracketed Spans [text]{.class} und Shortcut Reference Links [text]

set dir [file dirname [file normalize [info script]]]
tcl::tm::path add [file join $dir .. lib]

package require mdstack::parser 0.2

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
    set ast [mdstack::parser::parse $md]
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

set ast [mdstack::parser::parse $md]
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

set ast [mdstack::parser::parse $md]
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
set ast [mdstack::parser::parse $md]
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
set ast [mdstack::parser::parse $md]
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
# Fenced divs as TIP 700 writes them (2026-10-22)
# =========================================================================

set ast [mdstack::parser::parse "::: {.synopsis} :::\n\[after\]{.cmd} \[ms\]{.arg}\n\[after\]{.cmd} \[cancel\]{.sub}\n:::\n"]
set b [lindex [dict get $ast blocks] 0]
assert "synopsis: Zaun mit ::: am Ende ist ein div" {[dict get $b type] eq "div" && [dict get $b class] eq "synopsis"}
set kinds [lmap n [dict get [lindex [dict get $b blocks] 0] content] {dict get $n type}]
assert "synopsis: Zeilenumbruch wird harter Umbruch" {"linebreak" in $kinds && "softbreak" ni $kinds}

set ast [mdstack::parser::parse "::: {.info -version=\"9.0\"}\nNeu in 9.0.\n:::\n"]
set b [lindex [dict get $ast blocks] 0]
assert "info: Zaun mit Attribut ist ein div" {[dict get $b type] eq "div" && [dict get $b class] eq "info"}

set ast [mdstack::parser::parse "::: {.note}\na\nb\n:::\n"]
set kinds [lmap n [dict get [lindex [dict get [lindex [dict get $ast blocks] 0] blocks] 0] content] {dict get $n type}]
assert "andere divs: weicher Umbruch bleibt" {"softbreak" in $kinds}

# =========================================================================
# Attribute lists (parser 0.9.0): several classes, #id, key="value"
# =========================================================================

set n [firstInline {[\*interp]{.carg .in type="Tcl_Interp"}}]
assert "attr: span mit zwei Klassen und Attribut" {[dict get $n type] eq "span"}
assert "attr: class ist die Klassenliste" {[dict get $n class] eq "carg in"}
assert "attr: Klassen als Tcl-Liste" {[llength [dict get $n class]] == 2}
assert "attr: type im attrs-Dict" {[dict get $n attrs] eq {type Tcl_Interp}}
assert "attr: Text ohne Backslash" {[spanText $n] eq "*interp"}

set n [firstInline {[text]{version="TIP500"}}]
assert "attr: nur Attribut, keine Klasse -> span" {[dict get $n type] eq "span"}
assert "attr: leere Klasse" {[dict get $n class] eq ""}
assert "attr: version" {[dict get $n attrs version] eq "TIP500"}

set n [firstInline {[lfilter]{.cmd version="TIP735"}}]
assert "attr: .cmd bleibt Klasse cmd" {[dict get $n class] eq "cmd"}
assert "attr: .cmd + version" {[dict get $n attrs version] eq "TIP735"}

set n [firstInline {[x]{.info DISPLAY="yes"}}]
assert "attr: Grossbuchstaben-Schluessel" {[dict get $n class] eq "info" && [dict get $n attrs DISPLAY] eq "yes"}

set n [firstInline {[x]{#myid .a key=bare k2='single q'}}]
assert "attr: #id" {[dict get $n id] eq "myid"}
assert "attr: unquotierter und einfach quotierter Wert" {[dict get $n attrs key] eq "bare" && [dict get $n attrs k2] eq "single q"}

set n [firstInline {[p]{.carg .in/out type="int *"}}]
assert "attr: Klasse in/out wie geschrieben" {[dict get $n class] eq "carg in/out"}
assert "attr: Wert mit Leerzeichen" {[dict get $n attrs type] eq "int *"}

set n [firstInline "\[p\]\{.carg .(in) type=\"a\}b\"\}"]
set ::wantVal "a\}b"
assert "attr: Klasse (in), Klammer im Wert" {[dict get $n class] eq "carg (in)" && [dict get $n attrs type] eq $::wantVal}

set n [firstInline {[q]{t="say \"hi\""}}]
assert "attr: escapetes Anfuehrungszeichen" {[dict get $n attrs t] eq {say "hi"}}

# Keine Attributliste: Klammern bleiben Text
set inl [getInlines {Liste [a]{a b c} und {a b c} hier.}]
assert "attr: {a b c} nach ] ist kein span" {"span" ni [lmap n $inl {dict get $n type}]}
set txt [join [lmap n $inl {dict get $n value}] ""]
assert "attr: {a b c} bleibt Text" {$txt eq "Liste \[a\]{a b c} und {a b c} hier."}
set inl [getInlines {Werte [x]{} und [y]{2} und [z]{.a"b"}}]
assert "attr: {}, {2}, {.a\"b\"} sind keine spans" {"span" ni [lmap n $inl {dict get $n type}]}
set inl [getInlines {[a]{.k {x}}}]
assert "attr: geschweifte Klammer innen -> kein span" {"span" ni [lmap n $inl {dict get $n type}]}
assert "attr: einfacher span wie bisher" {[dict get [firstInline {[set]{.cmd}}] class] eq "cmd" && ![dict exists [firstInline {[set]{.cmd}}] attrs]}

# =========================================================================
# Section references (parser 0.9.0)
# =========================================================================

proc findLinks {inlines} {
    set out {}
    foreach n $inlines {
        if {[dict get $n type] eq "link"} { lappend out $n }
    }
    return $out
}

set ast [mdstack::parser::parse "# Name resolution\n\nSee \[Name resolution\] and \[Nowhere\].\n"]
set p [lindex [dict get $ast blocks] 1]
set links [findLinks [dict get $p content]]
assert "secref: Verweis wird Link" {[llength $links] == 1}
assert "secref: Ziel ist der Anker" {[dict get [lindex $links 0] url] eq "#name-resolution"}
assert "secref: ohne Ueberschrift bleibt Text" {[string first "\[Nowhere\]" [join [lmap n [dict get $p content] {expr {[dict exists $n value] ? [dict get $n value] : ""}}] ""]] >= 0}

# Ueberschrift nur im Codeblock: kein Link, der Text bleibt wie geschrieben
set ast [mdstack::parser::parse "```\n# Fake\n```\n\nSee \[Fake\].\n"]
set p [lindex [dict get $ast blocks] 1]
assert "secref: Ueberschrift im Code zaehlt nicht" {[llength [findLinks [dict get $p content]]] == 0}
set ast [mdstack::parser::parse "Fake\n\n    # Fake\n\nSee \[Fake\].\n"]
assert "secref: eingerueckter Code zaehlt nicht" {[llength [findLinks [dict get [lindex [dict get $ast blocks] 2] content]]] == 0}

# Linkdefinition hat Vorrang
set ast [mdstack::parser::parse "# Ex\n\n\[Ex\] text\n\n\[Ex\]: http://x.org\n"]
assert "secref: Linkdefinition gewinnt" {[dict get [lindex [findLinks [dict get [lindex [dict get $ast blocks] 1] content]] 0] url] eq "http://x.org"}

# Zusammengefuegtes Handbuch: jede Seite hat "Examples" -- der Verweis
# zeigt auf das Kapitel der eigenen Seite, nicht auf das erste
set md "# a\n\n## Description\n\nSee \[Examples\].\n\n## Examples\n\nA.\n\n# b\n\n## Description\n\nSee \[Examples\].\n\n## Examples\n\nB.\n\n# c\n\n## Examples\n\nC.\n\n## Description\n\nSee \[Examples\].\n"
set ast [mdstack::parser::parse $md]
set bl [dict get $ast blocks]
set urls {}
foreach b $bl {
    if {[dict get $b type] eq "paragraph"} {
        foreach l [findLinks [dict get $b content]] { lappend urls [dict get $l url] }
    }
}
assert "secref: drei Verweise" {[llength $urls] == 3}
assert "secref: Seite a -> erstes Examples (Anker)" {[lindex $urls 0] eq "#examples"}
assert "secref: Seite b -> eigenes Examples (Alias)" {[lindex $urls 1] eq "#examples-1"}
assert "secref: Seite c -> eigenes Examples (Alias), auch davor" {[lindex $urls 2] eq "#examples-2"}
set heads [lmap b $bl {if {[dict get $b type] ne "heading"} continue; set b}]
set exB [lindex $heads 5]
assert "secref: Alias steht an der Ueberschrift" {[dict exists $exB alias] && [dict get $exB alias] eq "examples-1"}
assert "secref: Ueberschrift ohne Verweis bekommt keinen Alias" {![dict exists [lindex $heads 2] alias]}

# Zusammengefuegtes Handbuch: [pwd] in der Seite glob ist kein Verweis auf
# die Seite pwd (Seitentitel sind keine Abschnitte der eigenen Seite)
set md "# glob\n\n## Name\n\nglob\n\n## Description\n\nset pwd \[pwd\]; see \[Examples\].\n\n# pwd\n\n## Name\n\npwd\n\n## Examples\n\nX.\n"
set ast [mdstack::parser::parse $md]
set p [lindex [dict get $ast blocks] 4]
assert "secref: Seitentitel einer anderen Seite ist kein Ziel" {[llength [findLinks [dict get $p content]]] == 0}
set txt [join [lmap n [dict get $p content] {expr {[dict exists $n value] ? [dict get $n value] : ""}}] ""]
assert "secref: Text bleibt wie geschrieben" {$txt eq "set pwd \[pwd\]; see \[Examples\]."}
# ... dieselben Abschnitte in einer einzelnen Seite: Geschwister sind Ziele
set ast [mdstack::parser::parse "# Name\n\nx\n\n# Description\n\n## Options\n\nSee \[Time zones\].\n\n# Time zones\n\nZ.\n"]
set p [lindex [dict get $ast blocks] 4]
assert "secref: einzelne Seite, Verweis aus Unterabschnitt auf Geschwister" {[dict get [lindex [findLinks [dict get $p content]] 0] url] eq "#time-zones"}

# Verweis in Definition, Liste, Tabelle und Zitat
set md "# Profiles\n\n**x**\n: see \[Profiles\]\n\n- in \[Profiles\]\n\n| a |\n|---|\n| \[Profiles\] |\n\n> quoted \[Profiles\]\n"
set ast [mdstack::parser::parse $md]
set bl [dict get $ast blocks]
set dl [lindex $bl 1]
set l1 [findLinks [lindex [dict get [lindex [dict get $dl items] 0] definitions] 0]]
assert "secref: in Definition" {[dict get [lindex $l1 0] url] eq "#profiles"}
set li [lindex [dict get [lindex $bl 2] items] 0]
set l2 [findLinks [dict get [lindex [dict get $li blocks] 0] content]]
assert "secref: in Listenpunkt" {[dict get [lindex $l2 0] url] eq "#profiles"}
set cell [lindex [dict get [lindex [dict get [lindex $bl 3] content] 1] content] 0]
assert "secref: in Tabellenzelle" {[dict get [lindex [findLinks [dict get $cell content]] 0] url] eq "#profiles"}
set q [lindex [dict get [lindex $bl 4] blocks] 0]
assert "secref: im Zitat" {[dict get [lindex [findLinks [dict get $q content]] 0] url] eq "#profiles"}

# --- 0.9.1: span holding a reference link; inline math switch -------------
set il [mdstack::parser::parseInlines {x [a [b][c] d]{version="1"} y}]
assert "span mit Referenzlink: Span erkannt" {[dict get [lindex $il 1] type] eq "span"}
assert "span mit Referenzlink: version" {[dict get [lindex $il 1] attrs] eq {version 1}}
set il [mdstack::parser::parseInlines {**$b** and **expr** then **$a**}]
assert "inlineMath 1: Mathe erkannt (Vorgabe)" {[string first "type math" $il] >= 0}
set ::mdstack::parser::inlineMath 0
set il [mdstack::parser::parseInlines {**$b** and **expr** then **$a**}]
set ::mdstack::parser::inlineMath 1
assert "inlineMath 0: keine Mathe, drei fett" {[lmap n $il {dict get $n type}] eq {strong text strong text strong}}

# --- 0.9.1: listContinuation ----------------------------------------------
set md "1. eins\n\n    weiter **fett**.\n\n    ```\n    code\n    ```\n\n2. zwei\n"
set bl [dict get [mdstack::parser::parse $md] blocks]
assert "listContinuation 0: alter Weg (Code-Block)" {[dict get [lindex $bl 1] type] eq "code_block"}
set ::mdstack::parser::listContinuation 1
set bl [dict get [mdstack::parser::parse $md] blocks]
set ::mdstack::parser::listContinuation 0
assert "listContinuation 1: eine Liste" {[llength $bl] == 1 && [dict get [lindex $bl 0] type] eq "list"}
set it [lindex [dict get [lindex $bl 0] items] 0]
assert "listContinuation 1: Absatz und Code im Punkt" {[lmap b [dict get $it blocks] {dict get $b type}] eq {paragraph paragraph code_block}}

# =========================================================================
puts ""
puts "=== parser-tip700.tcl ==="
puts "$passed/$total passed, $failed failed"
