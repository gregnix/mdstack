#!/usr/bin/env tclsh
# test/parser-reflinks.tcl
# Tests for Reference Links und Reference Images

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

proc getInline {para idx field} {
    set node [lindex [dict get $para content] $idx]
    dict get $node $field
}

proc hasInlineField {para idx field} {
    set node [lindex [dict get $para content] $idx]
    dict exists $node $field
}

proc linkLabelText {para idx} {
    set node [lindex [dict get $para content] $idx]
    set txt ""
    foreach i [dict get $node label] {
        if {[dict get $i type] eq "text"} { append txt [dict get $i value] }
    }
    return $txt
}

# ============================================================
# 1. Simple reference links
# ============================================================

set md {Text with [Example][ex] link.

[ex]: https://example.com}
set ast [mdparser::parse $md]
set p [lindex [dict get $ast blocks] 0]

assert "reflink-simple-type" {[getInline $p 1 type] eq "link"}
assert "reflink-simple-text" {[linkLabelText $p 1] eq "Example"}
assert "reflink-simple-url"  {[getInline $p 1 url] eq "https://example.com"}

# Mit Title
set md2 {Ein [Link][ref1] hier.

[ref1]: https://ref.com "Ref Title"}
set ast2 [mdparser::parse $md2]
set p2 [lindex [dict get $ast2 blocks] 0]

assert "reflink-title-url"   {[getInline $p2 1 url] eq "https://ref.com"}
assert "reflink-title-title" {[getInline $p2 1 title] eq "Ref Title"}

# ============================================================
# 2. Collapsed Reference Links [text][]
# ============================================================

set md3 {Klick [Google][] jetzt.

[google]: https://google.com}
set ast3 [mdparser::parse $md3]
set p3 [lindex [dict get $ast3 blocks] 0]

assert "reflink-collapsed-type" {[getInline $p3 1 type] eq "link"}
assert "reflink-collapsed-text" {[linkLabelText $p3 1] eq "Google"}
assert "reflink-collapsed-url"  {[getInline $p3 1 url] eq "https://google.com"}

# ============================================================
# 3. Case-Insensitive Lookup
# ============================================================

set md4 {Ein [Link][REF] hier.

[ref]: https://case.com}
set ast4 [mdparser::parse $md4]
set p4 [lindex [dict get $ast4 blocks] 0]

assert "reflink-case-insensitive" {[getInline $p4 1 url] eq "https://case.com"}

# Case-insensitive collapsed
set md5 {Ein [MyRef][] hier.

[myref]: https://myref.com}
set ast5 [mdparser::parse $md5]
set p5 [lindex [dict get $ast5 blocks] 0]

assert "reflink-case-collapsed" {[getInline $p5 1 url] eq "https://myref.com"}

# ============================================================
# 4. Undefined Reference → Kein Link
# ============================================================

set md6 {Hier [unknown][nope] Text.}
set ast6 [mdparser::parse $md6]
set p6 [lindex [dict get $ast6 blocks] 0]

# Sollte als plain text durchfallen, kein link-Node
set hasLink 0
foreach i [dict get $p6 content] {
    if {[dict get $i type] eq "link"} { set hasLink 1 }
}
assert "reflink-undefined-no-link" {$hasLink == 0}

# ============================================================
# 5. Reference Images
# ============================================================

set md7 {Image: ![Alt Text][img1]

[img1]: https://example.com/photo.jpg "Photo"}
set ast7 [mdparser::parse $md7]
set p7 [lindex [dict get $ast7 blocks] 0]

assert "refimage-type"  {[getInline $p7 1 type] eq "image"}
assert "refimage-alt"   {[getInline $p7 1 alt] eq "Alt Text"}
assert "refimage-url"   {[getInline $p7 1 url] eq "https://example.com/photo.jpg"}
assert "refimage-title" {[getInline $p7 1 title] eq "Photo"}

# Collapsed reference image
set md8 {Image: ![logo][]

[logo]: https://example.com/logo.png}
set ast8 [mdparser::parse $md8]
set p8 [lindex [dict get $ast8 blocks] 0]

assert "refimage-collapsed-type" {[getInline $p8 1 type] eq "image"}
assert "refimage-collapsed-url"  {[getInline $p8 1 url] eq "https://example.com/logo.png"}

# ============================================================
# 6. Multiple References in einem Dokument
# ============================================================

set md9 {Hier [A][a], [B][b] und [C][].

[a]: https://a.com
[b]: https://b.com "B"
[c]: https://c.com}
set ast9 [mdparser::parse $md9]
set p9 [lindex [dict get $ast9 blocks] 0]

assert "reflink-multi-a-url" {[getInline $p9 1 url] eq "https://a.com"}
assert "reflink-multi-b-url" {[getInline $p9 3 url] eq "https://b.com"}
assert "reflink-multi-c-url" {[getInline $p9 5 url] eq "https://c.com"}
assert "reflink-multi-b-title" {[getInline $p9 3 title] eq "B"}

# ============================================================
# 7. Definitionen werden nicht als Blocks gerendert
# ============================================================

set md10 {Paragraph eins.

[ref]: https://ref.com

Paragraph zwei.}
set ast10 [mdparser::parse $md10]
set blocks10 [dict get $ast10 blocks]

assert "refdef-not-in-blocks" {[llength $blocks10] == 2}
assert "refdef-para1" {[dict get [lindex $blocks10 0] type] eq "paragraph"}
assert "refdef-para2" {[dict get [lindex $blocks10 1] type] eq "paragraph"}

# ============================================================
# 8. Definitionen am Dokumentende
# ============================================================

set md11 {[Klick hier][end]

[end]: https://end.com}
set ast11 [mdparser::parse $md11]
set p11 [lindex [dict get $ast11 blocks] 0]

assert "refdef-at-end" {[getInline $p11 0 url] eq "https://end.com"}

# ============================================================
# 9. Erste Definition gewinnt (Duplikate)
# ============================================================

set md12 {[Link][dup] hier.

[dup]: https://first.com
[dup]: https://second.com}
set ast12 [mdparser::parse $md12]
set p12 [lindex [dict get $ast12 blocks] 0]

assert "refdef-first-wins" {[getInline $p12 0 url] eq "https://first.com"}

# ============================================================
# 10. Regular links remain unchanged
# ============================================================

set md13 {Ein [normaler](https://normal.com) Link und [ref][r].

[r]: https://ref.com}
set ast13 [mdparser::parse $md13]
set p13 [lindex [dict get $ast13 blocks] 0]

assert "reflink-normal-preserved-type" {[getInline $p13 1 type] eq "link"}
assert "reflink-normal-preserved-url"  {[getInline $p13 1 url] eq "https://normal.com"}
assert "reflink-ref-resolved"          {[getInline $p13 3 url] eq "https://ref.com"}

# ============================================================
# 11. Reference in Heading
# ============================================================

set md14 {## Heading mit [Link][h]

[h]: https://heading.com}
set ast14 [mdparser::parse $md14]
set h [lindex [dict get $ast14 blocks] 0]

assert "reflink-in-heading-type" {[dict get $h type] eq "heading"}
set hInlines [dict get $h content]
set hasHeadingLink 0
foreach i $hInlines {
    if {[dict get $i type] eq "link" && [dict get $i url] eq "https://heading.com"} {
        set hasHeadingLink 1
    }
}
assert "reflink-in-heading-resolved" {$hasHeadingLink == 1}

# ============================================================
# 12. Reference in table
# ============================================================

set md15 {| Header |
|--------|
| [Klick][t] |

[t]: https://table.com}
set ast15 [mdparser::parse $md15]
set tbl [lindex [dict get $ast15 blocks] 0]

assert "reflink-in-table-type" {[dict get $tbl type] eq "table"}
set cellInlines [lindex [lindex [dict get $tbl rowsInlines] 0] 0]
set hasTableLink 0
foreach i $cellInlines {
    if {[dict get $i type] eq "link" && [dict get $i url] eq "https://table.com"} {
        set hasTableLink 1
    }
}
assert "reflink-in-table-resolved" {$hasTableLink == 1}

# ============================================================
# 13. Reference in Blockquote
# ============================================================

set md16 {> Zitat mit [Link][q]

[q]: https://quote.com}
set ast16 [mdparser::parse $md16]
set bq [lindex [dict get $ast16 blocks] 0]

assert "reflink-in-blockquote-type" {[dict get $bq type] eq "blockquote"}
# Inner paragraph
set bqPara [lindex [dict get $bq blocks] 0]
set hasQuoteLink 0
foreach i [dict get $bqPara content] {
    if {[dict get $i type] eq "link" && [dict get $i url] eq "https://quote.com"} {
        set hasQuoteLink 1
    }
}
assert "reflink-in-blockquote-resolved" {$hasQuoteLink == 1}

# ============================================================
# 14. Reference in Liste
# ============================================================

set md17 {- Item mit [Link][l]

[l]: https://list.com}
set ast17 [mdparser::parse $md17]
set lst [lindex [dict get $ast17 blocks] 0]

assert "reflink-in-list-type" {[dict get $lst type] eq "list"}
set item0 [lindex [dict get $lst items] 0]
set hasListLink 0
foreach i [dict get [lindex [dict get $item0 blocks] 0] content] {
    if {[dict get $i type] eq "link" && [dict get $i url] eq "https://list.com"} {
        set hasListLink 1
    }
}
assert "reflink-in-list-resolved" {$hasListLink == 1}

# ============================================================
# 15. reflinks Dict im AST
# ============================================================

set md18 {Text.

[a]: https://a.com
[b]: https://b.com "Title B"}
set ast18 [mdparser::parse $md18]

assert "reflinks-in-ast" {[dict exists $ast18 reflinks]}
assert "reflinks-has-a"  {[dict exists [dict get $ast18 reflinks] a]}
assert "reflinks-has-b"  {[dict exists [dict get $ast18 reflinks] b]}
assert "reflinks-b-title" {[dict get [dict get [dict get $ast18 reflinks] b] title] eq "Title B"}

# ============================================================
# 16. Leeres Dokument ohne Referenzen
# ============================================================

set md19 {Simple text without references.}
set ast19 [mdparser::parse $md19]

assert "no-refs-empty-dict" {[dict size [dict get $ast19 reflinks]] == 0}

# ============================================================
# Result
# ============================================================

puts "[file tail [info script]]:\tTotal\t$total\tPassed\t$passed\tSkipped\t$skipped\tFailed\t$failed"
