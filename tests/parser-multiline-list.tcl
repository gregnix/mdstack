#!/usr/bin/env tclsh
# test/parser-multiline-list.tcl
# Tests for Multi-Line List Items

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
        if {[dict get $i type] eq "strong"} {
            foreach si [dict get $i content] {
                if {[dict get $si type] eq "text"} { append txt [dict get $si value] }
            }
        }
        if {[dict get $i type] eq "emphasis"} {
            foreach si [dict get $i content] {
                if {[dict get $si type] eq "text"} { append txt [dict get $si value] }
            }
        }
        if {[dict get $i type] eq "inline_code"} { append txt [dict get $i value] }
    }
    return $txt
}

# ============================================================
# 1. Simple multi-line (2 lines)
# ============================================================

set ast [mdparser::parse {- First item continues
  on this line.
- Second item.}]
set lst [getBlock $ast 0]

assert "ml-simple-count"  {[llength [dict get $lst items]] == 2}
assert "ml-simple-text"   {[itemText [getItem $lst 0]] eq "First item continues on this line."}
assert "ml-simple-item2"  {[itemText [getItem $lst 1]] eq "Second item."}

# ============================================================
# 2. Multi-line with 3 lines
# ============================================================

set ast [mdparser::parse {- Langer Text der
  spanning multiple
  lines here.
- Kurz.}]
set lst [getBlock $ast 0]

assert "ml-three-text" {[itemText [getItem $lst 0]] eq "Langer Text der spanning multiple lines here."}

# ============================================================
# 3. Multiple multi-line items
# ============================================================

set ast [mdparser::parse {- Erstes Item
  continues here.
- Zweites Item
  auch mehrzeilig.
- Drittes nur einzeilig.}]
set lst [getBlock $ast 0]

assert "ml-multi-count" {[llength [dict get $lst items]] == 3}
assert "ml-multi-item1" {[itemText [getItem $lst 0]] eq "Erstes Item continues here."}
assert "ml-multi-item2" {[itemText [getItem $lst 1]] eq "Zweites Item auch mehrzeilig."}
assert "ml-multi-item3" {[itemText [getItem $lst 2]] eq "Drittes nur einzeilig."}

# ============================================================
# 4. Ordered multi-line
# ============================================================

set ast [mdparser::parse {1. First step that
   is somewhat longer.
2. Second step.
3. Third continues
   on next line.}]
set lst [getBlock $ast 0]

assert "ml-ordered-count" {[llength [dict get $lst items]] == 3}
assert "ml-ordered-item1" {[itemText [getItem $lst 0]] eq "First step that is somewhat longer."}
assert "ml-ordered-item3" {[itemText [getItem $lst 2]] eq "Third continues on next line."}

# ============================================================
# 5. Multi-line + sub-items
# ============================================================

set ast [mdparser::parse {- Langer Text der
  continues here
  - Sub-Item A
  - Sub-Item B
- Zweites Item}]
set lst [getBlock $ast 0]

assert "ml-sub-count"    {[llength [dict get $lst items]] == 2}
assert "ml-sub-text"     {[itemText [getItem $lst 0]] eq "Langer Text der continues here"}
assert "ml-sub-children" {[llength [dict get [getItem $lst 0] blocks]] > 1}

set sub [lindex [dict get [getItem $lst 0] blocks] 1]
assert "ml-sub-sub-count" {[llength [dict get $sub items]] == 2}
assert "ml-sub-sub-a"     {[itemText [getItem $sub 0]] eq "Sub-Item A"}

# ============================================================
# 6. Inline formatting across line boundaries
# ============================================================

set ast [mdparser::parse {- Text mit **bold**
  and *italic* words.
- Normal.}]
set lst [getBlock $ast 0]
set item0 [getItem $lst 0]

# Check that bold and italic are recognized
set hasStrong 0
set hasEm 0
foreach i [dict get [lindex [dict get $item0 blocks] 0] content] {
    if {[dict get $i type] eq "strong"} { set hasStrong 1 }
    if {[dict get $i type] eq "emphasis"} { set hasEm 1 }
}
assert "ml-inline-strong" {$hasStrong == 1}
assert "ml-inline-em"     {$hasEm == 1}

# ============================================================
# 7. Backward compatibility: Flache Liste
# ============================================================

set ast [mdparser::parse {- A
- B
- C}]
set lst [getBlock $ast 0]

assert "ml-compat-count" {[llength [dict get $lst items]] == 3}
assert "ml-compat-item1" {[itemText [getItem $lst 0]] eq "A"}

# ============================================================
# 8. Backward compatibility: Nested ohne Multi-Line
# ============================================================

set ast [mdparser::parse {- Top
  - Sub
- Top 2}]
set lst [getBlock $ast 0]

assert "ml-compat-nested-count" {[llength [dict get $lst items]] == 2}
assert "ml-compat-nested-text"  {[itemText [getItem $lst 0]] eq "Top"}
assert "ml-compat-nested-has-children" {[llength [dict get [getItem $lst 0] blocks]] > 1}

# ============================================================
# 9. Code in multi-line
# ============================================================

set ast [mdparser::parse {- Use `command`
  for execution.
- Other item.}]
set lst [getBlock $ast 0]

assert "ml-code-text" {[itemText [getItem $lst 0]] eq "Use command for execution."}

# ============================================================
# 10. Blank line ends multi-line (no code block swallowing)
# ============================================================

set ast [mdparser::parse {- Item eins.
- Item zwei.

    code block}]
set blocks [dict get $ast blocks]

assert "ml-blank-stops-count" {[llength $blocks] == 2}
assert "ml-blank-stops-list"  {[dict get [lindex $blocks 0] type] eq "list"}
assert "ml-blank-stops-code"  {[dict get [lindex $blocks 1] type] eq "code_block"}

# ============================================================
# 11. Task list multi-line
# ============================================================

set ast [mdparser::parse {- [ ] Task that
  is somewhat longer.
- [x] Erledigt.}]
set lst [getBlock $ast 0]

assert "ml-task-text"    {[itemText [getItem $lst 0]] eq "Task that is somewhat longer."}
assert "ml-task-checked" {[dict get [getItem $lst 0] checked] == 0}
assert "ml-task-done"    {[dict get [getItem $lst 1] checked] == 1}

# ============================================================
# 12. 4-space indentation as continuation
# ============================================================

set ast [mdparser::parse {- Item mit
    four spaces indentation.
- Next.}]
set lst [getBlock $ast 0]

assert "ml-4space-text" {[itemText [getItem $lst 0]] eq "Item mit four spaces indentation."}

# ============================================================
# 13. Paragraph vor und nach Liste bleibt erhalten
# ============================================================

set ast [mdparser::parse {Text davor.

- Mehrzeiliges
  Item hier.

Text danach.}]
set blocks [dict get $ast blocks]

assert "ml-context-count" {[llength $blocks] == 3}
assert "ml-context-para1" {[dict get [lindex $blocks 0] type] eq "paragraph"}
assert "ml-context-list"  {[dict get [lindex $blocks 1] type] eq "list"}
assert "ml-context-para2" {[dict get [lindex $blocks 2] type] eq "paragraph"}

# ============================================================
# Result
# ============================================================

puts "[file tail [info script]]:\tTotal\t$total\tPassed\t$passed\tSkipped\t$skipped\tFailed\t$failed"
