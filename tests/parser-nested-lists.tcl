#!/usr/bin/env tclsh
# test/parser-nested-lists.tcl
# Tests for nested lists

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
proc itemText {item} {
    set firstBlock [lindex [dict get $item blocks] 0]
    set txt ""
    foreach i [dict get $firstBlock content] {
        if {[dict get $i type] eq "text"} { append txt [dict get $i value] }
    }
    return $txt
}
proc hasSubBlocks {item} {
    expr {[llength [dict get $item blocks]] > 1}
}
proc getSubList {item} {
    lindex [dict get $item blocks] 1
}

# ============================================================
# 1. Flache Liste (Rueckwaertskompatibilitaet)
# ============================================================

set ast [mdparser::parse {- Alpha
- Beta
- Gamma}]
set lst [getBlock $ast 0]

assert "flat-type"     {[dict get $lst type] eq "list"}
assert "flat-count"    {[llength [dict get $lst items]] == 3}
assert "flat-ordered"  {[dict get $lst style] eq "unordered"}
assert "flat-item1"    {[itemText [getItem $lst 0]] eq "Alpha"}
assert "flat-item3"    {[itemText [getItem $lst 2]] eq "Gamma"}
assert "flat-no-children" {![hasSubBlocks [getItem $lst 0]]}

# ============================================================
# 2. Simple nesting (2 levels)
# ============================================================

set ast [mdparser::parse {- Item 1
  - Sub A
  - Sub B
- Item 2}]
set lst [getBlock $ast 0]

assert "nest2-count"   {[llength [dict get $lst items]] == 2}
assert "nest2-item1"   {[itemText [getItem $lst 0]] eq "Item 1"}
assert "nest2-item2"   {[itemText [getItem $lst 1]] eq "Item 2"}
assert "nest2-has-children" {[hasSubBlocks [getItem $lst 0]]}
assert "nest2-no-children-item2" {![hasSubBlocks [getItem $lst 1]]}

set sub [getSubList [getItem $lst 0]]
assert "nest2-sub-type"    {[dict get $sub type] eq "list"}
assert "nest2-sub-count"   {[llength [dict get $sub items]] == 2}
assert "nest2-sub-item1"   {[itemText [getItem $sub 0]] eq "Sub A"}
assert "nest2-sub-item2"   {[itemText [getItem $sub 1]] eq "Sub B"}

# ============================================================
# 3. Drei Ebenen
# ============================================================

set ast [mdparser::parse {- L1
  - L2
    - L3
  - L2b
- L1b}]
set lst [getBlock $ast 0]

assert "nest3-count"   {[llength [dict get $lst items]] == 2}
set sub2 [getSubList [getItem $lst 0]]
assert "nest3-l2-count" {[llength [dict get $sub2 items]] == 2}
assert "nest3-l2-item1" {[itemText [getItem $sub2 0]] eq "L2"}

set sub3 [getSubList [getItem $sub2 0]]
assert "nest3-l3-count" {[llength [dict get $sub3 items]] == 1}
assert "nest3-l3-item1" {[itemText [getItem $sub3 0]] eq "L3"}

# ============================================================
# 4. Gemischt ordered/unordered
# ============================================================

set ast [mdparser::parse {1. First
   - Sub unordered
   - Sub zwei
2. Second
3. Third}]
set lst [getBlock $ast 0]

assert "mixed-ordered"     {[dict get $lst style] eq "ordered"}
assert "mixed-count"       {[llength [dict get $lst items]] == 3}
assert "mixed-has-children" {[hasSubBlocks [getItem $lst 0]]}

set sub [getSubList [getItem $lst 0]]
assert "mixed-sub-unordered" {[dict get $sub style] eq "unordered"}
assert "mixed-sub-count"     {[llength [dict get $sub items]] == 2}

# ============================================================
# 5. Task list nested
# ============================================================

set ast [mdparser::parse {- [ ] Todo 1
  - [x] Sub done
  - [ ] Sub open
- [x] Todo 2}]
set lst [getBlock $ast 0]

assert "task-item1-checked"  {[dict get [getItem $lst 0] checked] == 0}
assert "task-item2-checked"  {[dict get [getItem $lst 1] checked] == 1}

set sub [getSubList [getItem $lst 0]]
assert "task-sub1-checked"   {[dict get [getItem $sub 0] checked] == 1}
assert "task-sub2-checked"   {[dict get [getItem $sub 1] checked] == 0}

# ============================================================
# 6. 4-Space Einrueckung
# ============================================================

set ast [mdparser::parse {- Item
    - Sub 4 spaces
- Item 2}]
set lst [getBlock $ast 0]

assert "4space-children" {[hasSubBlocks [getItem $lst 0]]}
set sub [getSubList [getItem $lst 0]]
assert "4space-sub-text" {[itemText [getItem $sub 0]] eq "Sub 4 spaces"}

# ============================================================
# 7. Inline formatting in nested items
# ============================================================

set ast [mdparser::parse {- **Bold** item
  - *Italic* sub}]
set lst [getBlock $ast 0]

set item0 [getItem $lst 0]
set hasStrong 0
foreach i [dict get [lindex [dict get $item0 blocks] 0] content] {
    if {[dict get $i type] eq "strong"} { set hasStrong 1 }
}
assert "inline-strong-top" {$hasStrong == 1}

set sub [getSubList $item0]
set hasEm 0
foreach i [dict get [lindex [dict get [getItem $sub 0] blocks] 0] content] {
    if {[dict get $i type] eq "emphasis"} { set hasEm 1 }
}
assert "inline-em-sub" {$hasEm == 1}

# ============================================================
# 8. Ordered list nested
# ============================================================

set ast [mdparser::parse {1. Eins
   1. Sub eins
   2. Sub zwei
2. Zwei}]
set lst [getBlock $ast 0]

assert "ord-nested-count" {[llength [dict get $lst items]] == 2}
set sub [getSubList [getItem $lst 0]]
assert "ord-nested-sub-ordered" {[dict get $sub style] eq "ordered"}
assert "ord-nested-sub-count"   {[llength [dict get $sub items]] == 2}

# ============================================================
# 9. Mehrere Items mit je eigenen Kindern
# ============================================================

set ast [mdparser::parse {- A
  - A1
  - A2
- B
  - B1
- C}]
set lst [getBlock $ast 0]

assert "multi-children-count" {[llength [dict get $lst items]] == 3}
assert "multi-A-children" {[hasSubBlocks [getItem $lst 0]]}
assert "multi-B-children" {[hasSubBlocks [getItem $lst 1]]}
assert "multi-C-no-children" {![hasSubBlocks [getItem $lst 2]]}

set subA [getSubList [getItem $lst 0]]
set subB [getSubList [getItem $lst 1]]
assert "multi-A-sub-count" {[llength [dict get $subA items]] == 2}
assert "multi-B-sub-count" {[llength [dict get $subB items]] == 1}

# ============================================================
# 10. Only one block type (no interference with other blocks)
# ============================================================

set ast [mdparser::parse {Paragraph davor.

- Item
  - Sub

Paragraph danach.}]

assert "blocks-count" {[llength [dict get $ast blocks]] == 3}
assert "blocks-0-para" {[dict get [getBlock $ast 0] type] eq "paragraph"}
assert "blocks-1-list" {[dict get [getBlock $ast 1] type] eq "list"}
assert "blocks-2-para" {[dict get [getBlock $ast 2] type] eq "paragraph"}

# ============================================================
# Result
# ============================================================

puts "[file tail [info script]]:\tTotal\t$total\tPassed\t$passed\tSkipped\t$skipped\tFailed\t$failed"
