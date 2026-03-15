#!/usr/bin/env tclsh
# validator.tcl -- Tests fuer mdvalidator

set dir [file dirname [file normalize [info script]]]
tcl::tm::path add [file join $dir .. lib]

package require mdparser 0.2
package require mdvalidator 0.1

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
# A: Valide ASTs
# =========================================================================

set md {# Heading

Paragraph with **bold** and *em* and `code`.

```tcl
puts "hi"
```

* Item 1
* Item 2

> A quote

---
}

set ast [mdparser::parse $md]
set errs [mdvalidator::validate $ast]
assert "A1: standard markdown valid" {[llength $errs] == 0}

# With table
set md {| A | B |
|---|---|
| 1 | 2 |
}
set ast [mdparser::parse $md]
set errs [mdvalidator::validate $ast]
assert "A2: table valid" {[llength $errs] == 0}

# With deflist
set md {Term
: Definition
}
set ast [mdparser::parse $md]
set errs [mdvalidator::validate $ast]
assert "A3: deflist valid" {[llength $errs] == 0}

# With TIP 700 features
set md {---
title: array
---

::: {.synopsis}
[array]{.cmd} [option]{.arg}
:::

See the [encoding] command.

[encoding]: encoding.md
}
set ast [mdparser::parse $md]
set errs [mdvalidator::validate $ast]
assert "A4: TIP 700 features valid" {[llength $errs] == 0}

# Complex nested
set md {## Title

A paragraph with [**bold link**](http://ex.com "Title") and ~~strike~~.

1. First
2. Second
   * Nested

> > Nested quote
}
set ast [mdparser::parse $md]
set errs [mdvalidator::validate $ast]
assert "A5: complex nested valid" {[llength $errs] == 0}

# Task list
set md {- [x] Done
- [ ] Todo
}
set ast [mdparser::parse $md]
set errs [mdvalidator::validate $ast]
assert "A6: task list valid" {[llength $errs] == 0}

# Indented code
set md {    code line 1
    code line 2
}
set ast [mdparser::parse $md]
set errs [mdvalidator::validate $ast]
assert "A7: indented code valid" {[llength $errs] == 0}

# Empty document
set ast [mdparser::parse ""]
set errs [mdvalidator::validate $ast]
assert "A8: empty doc valid" {[llength $errs] == 0}

# Image
set md {![alt text](image.png "title")}
set ast [mdparser::parse $md]
set errs [mdvalidator::validate $ast]
assert "A9: inline image valid" {[llength $errs] == 0}

# Standalone image
set md {![alt](image.png)
}
set ast [mdparser::parse $md]
set errs [mdvalidator::validate $ast]
assert "A10: standalone image valid" {[llength $errs] == 0}

# =========================================================================
# B: Kaputte ASTs (manuell konstruiert)
# =========================================================================

# No type field
set errs [mdvalidator::validate [dict create blocks {}]]
assert "B1: missing type detected" {[llength $errs] > 0}

# Wrong root type
set errs [mdvalidator::validate [dict create type paragraph content {}]]
assert "B2: wrong root type detected" {[llength $errs] > 0}

# Missing blocks
set errs [mdvalidator::validate [dict create type document version 1 meta {} reflinks {}]]
assert "B3: missing blocks detected" {[llength $errs] > 0}

# Block without type
set ast [dict create type document version 1 meta {} blocks [list [dict create foo bar]] reflinks {}]
set errs [mdvalidator::validate $ast]
assert "B4: block without type" {[llength $errs] > 0}

# Heading with wrong level
set ast [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type heading level 7 content [list [dict create type text value "X"]] anchor "x"]]]
set errs [mdvalidator::validate $ast]
assert "B5: heading level 7 invalid" {[llength $errs] > 0}

# code_block without language
set ast [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type code_block text "code"]]]
set errs [mdvalidator::validate $ast]
assert "B6: code_block without language" {[llength $errs] > 0}

# list with wrong style
set ast [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type list style "bullets" items {}]]]
set errs [mdvalidator::validate $ast]
assert "B7: list wrong style" {[llength $errs] > 0}

# list_item without type
set ast [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type list style unordered items [list \
        [dict create blocks [list [dict create type paragraph content [list [dict create type text value "x"]]]]]] \
    ]]]
set errs [mdvalidator::validate $ast]
assert "B8: list_item without type" {[llength $errs] > 0}

# Inline without type
set ast [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type paragraph content [list [dict create value "x"]]]]]
set errs [mdvalidator::validate $ast]
assert "B9: inline without type" {[llength $errs] > 0}

# Link without url
set ast [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type paragraph content [list \
        [dict create type link label [list [dict create type text value "x"]]]]]]]
set errs [mdvalidator::validate $ast]
assert "B10: link without url" {[llength $errs] > 0}

# span without class
set ast [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type paragraph content [list \
        [dict create type span content [list [dict create type text value "x"]]]]]]]
set errs [mdvalidator::validate $ast]
assert "B11: span without class" {[llength $errs] > 0}

# div without class
set ast [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type div blocks {}]]]
set errs [mdvalidator::validate $ast]
assert "B12: div without class" {[llength $errs] > 0}

# table with wrong alignment
set ast [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type table header {A} alignments {middle} rows {} headerInlines {} rowsInlines {}]]]
set errs [mdvalidator::validate $ast]
assert "B13: table wrong alignment" {[llength $errs] > 0}

# =========================================================================
# C: report Funktion
# =========================================================================

set md {# Test

Some text.
}
set ast [mdparser::parse $md]
set r [mdvalidator::report $ast]
assert "C1: report valid" {[string match "*valide*" $r]}

set r [mdvalidator::report [dict create type paragraph]]
assert "C2: report errors" {[string match "*error*" $r] || [string match "*Fehler*" $r]}

# =========================================================================
# D: Strict-Modus
# =========================================================================

# Unknown block type (warning only in normal, error in strict)
set ast [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type custom_widget foo bar]]]
set errs_normal [mdvalidator::validate $ast]
set errs_strict [mdvalidator::validate $ast -strict]
assert "D1: unknown type ok in normal" {[llength $errs_normal] == 0}
assert "D2: unknown type error in strict" {[llength $errs_strict] > 0}

# =========================================================================
# E: Alle realen Testdateien validieren
# =========================================================================

set testfiles {
    {# H1

Paragraph}
    {* Item 1
* Item 2
* Item 3}
    {> Quote
> with **bold**}
    {Term
: Def 1
: Def 2}
    {| A | B |
|:--|--:|
| x | y |}
    {---
title: test
---

::: {.synopsis}
[cmd]{.cmd} [arg]{.arg}
:::}
    {1. First
2. Second
   - Nested a
   - Nested b}
    {Text with [link](url), ![img](img.png), `code`, **bold**, *em*, ~~strike~~.}
    {- [x] Done
- [ ] Not done}
}

set idx 0
foreach md $testfiles {
    incr idx
    set ast [mdparser::parse $md]
    set errs [mdvalidator::validate $ast]
    assert "E$idx: real test $idx valid" {[llength $errs] == 0}
}

# =========================================================================


# =========================================================================
# F: Alte AST-Feldnamen (Pre-Phase-2 Regressionen)
# =========================================================================

# type code statt code_block
set ast [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type code lang "tcl" text "puts hi"]]]
set errs [mdvalidator::validate $ast -strict]
assert "F1: old type code detected" {[llength $errs] > 0}

# inlines statt content
set ast [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type paragraph inlines [list [dict create type text value "x"]]]]]
set errs [mdvalidator::validate $ast]
assert "F2: inlines statt content" {[llength $errs] > 0}

# type em statt emphasis
set ast [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type paragraph content [list [dict create type em inlines {}]]]]]
set errs [mdvalidator::validate $ast -strict]
assert "F3: old type em detected" {[llength $errs] > 0}

# type code_inline statt inline_code
set ast [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type paragraph content [list [dict create type code_inline text "x"]]]]]
set errs [mdvalidator::validate $ast -strict]
assert "F4: old type code_inline detected" {[llength $errs] > 0}

# ordered 0/1 statt style
set ast [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type list ordered 0 items {}]]]
set errs [mdvalidator::validate $ast]
assert "F5: old ordered field detected" {[llength $errs] > 0}

# text.text statt text.value
set ast [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type paragraph content [list [dict create type text text "x"]]]]]
set errs [mdvalidator::validate $ast]
assert "F6: text.text statt text.value" {[llength $errs] > 0}

# =========================================================================
# Aktualisierte Zusammenfassung
puts ""
puts "=== validator.tcl (erweitert) ==="
puts "$passed/$total passed, $failed failed"
