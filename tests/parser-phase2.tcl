#!/usr/bin/env tclsh
# ============================================================
# Tests fuer Phase 2: Link-Label inline[], list_item Block-Modell
# ============================================================

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
proc getItem {lst idx} { lindex [dict get $lst items] $idx }

# Flatten inline[] to plain text (recursive)
proc flatLabel {inlines} {
    set txt ""
    foreach i $inlines {
        switch [dict get $i type] {
            text       { append txt [dict get $i value] }
            inline_code { append txt [dict get $i value] }
            strong - emphasis - strike {
                append txt [flatLabel [dict get $i content]]
            }
            link { append txt [flatLabel [dict get $i label]] }
        }
    }
    return $txt
}

# ============================================================
# A. Link label ist inline[] (nicht mehr String)
# ============================================================

puts "--- A. Link label als inline\[\] ---"

# A1. Simple link: label is list with one text node
set r [mdparser::parseInlines {[Tcl](https://tcl.tk)}]
set link [lindex $r 0]
assert "A1-link-type"       {[dict get $link type] eq "link"}
assert "A1-label-is-list"   {[llength [dict get $link label]] >= 1}
assert "A1-label-text"      {[flatLabel [dict get $link label]] eq "Tcl"}
assert "A1-url"             {[dict get $link url] eq "https://tcl.tk"}

# A2. Formatierter Link: **bold** im Label
set r [mdparser::parseInlines {[**Bold** link](https://example.com)}]
set link [lindex $r 0]
assert "A2-label-has-strong" {[dict get [lindex [dict get $link label] 0] type] eq "strong"}
assert "A2-label-flat"       {[flatLabel [dict get $link label]] eq "Bold link"}

# A3. Link mit inline_code im Label
set r [mdparser::parseInlines {[`code` ref](https://example.com)}]
set link [lindex $r 0]
set first [lindex [dict get $link label] 0]
assert "A3-label-has-code"  {[dict get $first type] eq "inline_code"}
assert "A3-label-flat"      {[flatLabel [dict get $link label]] eq "code ref"}

# A4. Link mit emphasis im Label
set r [mdparser::parseInlines {[*italic* text](https://example.com)}]
set link [lindex $r 0]
assert "A4-label-has-em"    {[dict get [lindex [dict get $link label] 0] type] eq "emphasis"}
assert "A4-label-flat"      {[flatLabel [dict get $link label]] eq "italic text"}

# A5. Autolink: label ist auch inline[]
set r [mdparser::parseInlines {<https://example.com>}]
set link [lindex $r 0]
assert "A5-autolink-label-list" {[llength [dict get $link label]] >= 1}
assert "A5-autolink-label-text" {[flatLabel [dict get $link label]] eq "https://example.com"}

# A6. Bare URL: label ist inline[]
set r [mdparser::parseInlines {visit https://example.com today}]
set link [lindex $r 1]
assert "A6-bare-label-list" {[llength [dict get $link label]] >= 1}
assert "A6-bare-label-text" {[flatLabel [dict get $link label]] eq "https://example.com"}

# A7. Mailto autolink: label ist inline[]
set r [mdparser::parseInlines {mail <user@example.com> bitte}]
set link [lindex $r 1]
assert "A7-mailto-label-list" {[llength [dict get $link label]] >= 1}
assert "A7-mailto-label-text" {[flatLabel [dict get $link label]] eq "user@example.com"}

# A8. Link mit Title: label ist inline[]
set r [mdparser::parseInlines {[Tcl](https://tcl.tk "The Tcl Language")}]
set link [lindex $r 0]
assert "A8-title-present"  {[dict get $link title] eq "The Tcl Language"}
assert "A8-label-is-list"  {[llength [dict get $link label]] >= 1}
assert "A8-label-flat"     {[flatLabel [dict get $link label]] eq "Tcl"}

# ============================================================
# B. list_item hat type + blocks (nicht mehr content/children)
# ============================================================

puts "--- B. list_item Block-Modell ---"

# B1. Simple list: items have type list_item + blocks
set ast [mdparser::parse {- Alpha
- Beta}]
set lst [getBlock $ast 0]
set item [getItem $lst 0]

assert "B1-item-type"       {[dict get $item type] eq "list_item"}
assert "B1-item-has-blocks"  {[dict exists $item blocks]}
assert "B1-blocks-count"     {[llength [dict get $item blocks]] == 1}

set para [lindex [dict get $item blocks] 0]
assert "B1-first-block-para" {[dict get $para type] eq "paragraph"}
assert "B1-para-has-content" {[dict exists $para content]}

# B2. Item-Text korrekt
set inlines [dict get $para content]
assert "B2-text-value" {[dict get [lindex $inlines 0] value] eq "Alpha"}

# B3. Nested list: sub-list is second block in item
set ast [mdparser::parse {- Parent
  - Child A
  - Child B}]
set lst [getBlock $ast 0]
set item [getItem $lst 0]

assert "B3-parent-blocks"    {[llength [dict get $item blocks]] == 2}

set subList [lindex [dict get $item blocks] 1]
assert "B3-sub-is-list"      {[dict get $subList type] eq "list"}
assert "B3-sub-count"        {[llength [dict get $subList items]] == 2}

set childItem [getItem $subList 0]
assert "B3-child-type"       {[dict get $childItem type] eq "list_item"}
assert "B3-child-blocks"     {[llength [dict get $childItem blocks]] == 1}

# B4. Ordered list items haben auch type list_item
set ast [mdparser::parse {1. Eins
2. Zwei}]
set lst [getBlock $ast 0]
assert "B4-ordered"          {[dict get $lst style] eq "ordered"}
assert "B4-item-type"        {[dict get [getItem $lst 0] type] eq "list_item"}

# B5. Task list: checked auf Item-Ebene (nicht im Paragraph)
set ast [mdparser::parse {- [x] Done
- [ ] Open}]
set lst [getBlock $ast 0]
set item0 [getItem $lst 0]
set item1 [getItem $lst 1]

assert "B5-type"             {[dict get $item0 type] eq "list_item"}
assert "B5-checked-done"     {[dict get $item0 checked] == 1}
assert "B5-checked-open"     {[dict get $item1 checked] == 0}
assert "B5-has-blocks"       {[dict exists $item0 blocks]}

# B6. Kein children-Key mehr vorhanden
set ast [mdparser::parse {- Parent
  - Child}]
set item [getItem [getBlock $ast 0] 0]
assert "B6-no-children-key"  {![dict exists $item children]}

# B7. Kein direkter content-Key auf Item (nur in Paragraph-Block)
assert "B7-no-content-key"   {![dict exists $item content]}

# B8. Multi-line item: Text wird zusammengefuegt im Paragraph
set ast [mdparser::parse {- Langer Text
  der continues here.
- Kurz.}]
set lst [getBlock $ast 0]
set para [lindex [dict get [getItem $lst 0] blocks] 0]
set flat ""
foreach i [dict get $para content] {
    if {[dict get $i type] eq "text"} { append flat [dict get $i value] }
}
assert "B8-multiline-joined" {$flat eq "Langer Text der continues here."}

# B9. Formatting in item: strong in paragraph block
set ast [mdparser::parse {- **Bold** item}]
set lst [getBlock $ast 0]
set para [lindex [dict get [getItem $lst 0] blocks] 0]
set hasStrong 0
foreach i [dict get $para content] {
    if {[dict get $i type] eq "strong"} { set hasStrong 1 }
}
assert "B9-strong-in-para" {$hasStrong == 1}

# B10. Triple nested: blocks correct
set ast [mdparser::parse {- L1
  - L2
    - L3}]
set lst [getBlock $ast 0]
set item1 [getItem $lst 0]
assert "B10-l1-blocks"      {[llength [dict get $item1 blocks]] == 2}

set sub2 [lindex [dict get $item1 blocks] 1]
set item2 [getItem $sub2 0]
assert "B10-l2-blocks"      {[llength [dict get $item2 blocks]] == 2}

set sub3 [lindex [dict get $item2 blocks] 1]
assert "B10-l3-type"        {[dict get $sub3 type] eq "list"}
assert "B10-l3-item-type"   {[dict get [getItem $sub3 0] type] eq "list_item"}

# ============================================================
# C. Refactored Parser: parseBlocks korrekt
# ============================================================

puts "--- C. parseBlocks Dispatcher ---"

# C1. Alle Block-Typen werden erkannt
set ast [mdparser::parse {# Heading

Paragraph text.

```tcl
puts hello
```

- List item

> Blockquote

---

![img](test.png)

| H1 | H2 |
|----|-----|
| A  | B  |

Term
: Definition
}]

set blocks [dict get $ast blocks]
set types {}
foreach b $blocks { lappend types [dict get $b type] }

assert "C1-has-heading"    {"heading" in $types}
assert "C1-has-paragraph"  {"paragraph" in $types}
assert "C1-has-code"       {"code_block" in $types}
assert "C1-has-list"       {"list" in $types}
assert "C1-has-blockquote" {"blockquote" in $types}
assert "C1-has-hr"         {"hr" in $types}
assert "C1-has-image"      {"image" in $types}
assert "C1-has-table"      {"table" in $types}
assert "C1-has-deflist"    {"deflist" in $types}

# C2. Reihenfolge bleibt korrekt
assert "C2-first-heading"  {[dict get [lindex $blocks 0] type] eq "heading"}

# ============================================================
# D. Reference Links: label ist inline[]
# ============================================================

puts "--- D. Reference Links ---"

set ast [mdparser::parse {See [**bold** ref][r1] here.

[r1]: https://example.com "Title"}]
set para [getBlock $ast 0]
set inlines [dict get $para content]

# Finde den Link
set refLink ""
foreach i $inlines {
    if {[dict get $i type] eq "link"} { set refLink $i; break }
}
assert "D1-reflink-found"   {$refLink ne ""}
assert "D1-label-is-list"   {[llength [dict get $refLink label]] >= 1}
assert "D1-label-has-strong" {[dict get [lindex [dict get $refLink label] 0] type] eq "strong"}
assert "D1-label-flat"      {[flatLabel [dict get $refLink label]] eq "bold ref"}

# ============================================================
# Result
# ============================================================

puts ""
puts "[file tail [info script]]:\tTotal\t$total\tPassed\t$passed\tSkipped\t$skipped\tFailed\t$failed"
