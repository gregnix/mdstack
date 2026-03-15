#!/usr/bin/env tclsh
# parser-tip700-t2t3.tcl -- Tests fuer YAML Frontmatter und Fenced Divs

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
# A: YAML Frontmatter -- Basics
# =========================================================================

set md {---
title: array
section: n
---

# Array Command
}

set ast [mdparser::parse $md]
set meta [dict get $ast meta]
assert "A1: meta is dict" {[llength [dict keys $meta]] > 0}
assert "A2: title" {[dict get $meta title] eq "array"}
assert "A3: section" {[dict get $meta section] eq "n"}

set blocks [dict get $ast blocks]
assert "A4: heading after frontmatter" {[dict get [lindex $blocks 0] type] eq "heading"}

# =========================================================================
# B: YAML Frontmatter -- Kein Frontmatter
# =========================================================================

set md {# Normal Heading

Some text.
}

set ast [mdparser::parse $md]
set meta [dict get $ast meta]
assert "B1: empty meta without frontmatter" {[llength [dict keys $meta]] == 0}

set blocks [dict get $ast blocks]
assert "B2: heading still works" {[dict get [lindex $blocks 0] type] eq "heading"}

# =========================================================================
# C: YAML Frontmatter -- Mehrere Felder
# =========================================================================

set md {---
title: puts
section: n
manual-section: Tcl Built-In Commands
version: 9.0
---

# puts
}

set ast [mdparser::parse $md]
set meta [dict get $ast meta]
assert "C1: title" {[dict get $meta title] eq "puts"}
assert "C2: section" {[dict get $meta section] eq "n"}
assert "C3: manual-section" {[dict get $meta manual-section] eq "Tcl Built-In Commands"}
assert "C4: version" {[dict get $meta version] eq "9.0"}

# =========================================================================
# D: YAML Frontmatter -- Closing with ...
# =========================================================================

set md {---
title: test
...

Some text.
}

set ast [mdparser::parse $md]
set meta [dict get $ast meta]
assert "D1: dots closer works" {[dict get $meta title] eq "test"}

# =========================================================================
# E: YAML Frontmatter -- Leerer Wert
# =========================================================================

set md {---
title: array
keywords:
---

Text.
}

set ast [mdparser::parse $md]
set meta [dict get $ast meta]
assert "E1: empty value" {[dict get $meta keywords] eq ""}
assert "E2: title still works" {[dict get $meta title] eq "array"}

# =========================================================================
# F: YAML frontmatter -- no match if --- not on first line
# =========================================================================

set md {Some text.

---

More text.
}

set ast [mdparser::parse $md]
set meta [dict get $ast meta]
assert "F1: hr not mistaken for frontmatter" {[llength [dict keys $meta]] == 0}

# =========================================================================
# G: Fenced divs -- simple
# =========================================================================

set md {::: {.synopsis}
[puts]{.cmd} [string]{.arg}
:::
}

set ast [mdparser::parse $md]
set blocks [dict get $ast blocks]
set div [lindex $blocks 0]
assert "G1: div type" {[dict get $div type] eq "div"}
assert "G2: div class" {[dict get $div class] eq "synopsis"}

set inner [dict get $div blocks]
assert "G3: has inner blocks" {[llength $inner] > 0}
set para [lindex $inner 0]
assert "G4: inner paragraph" {[dict get $para type] eq "paragraph"}

# Check spans inside
set inlines [dict get $para content]
set firstSpan [lindex $inlines 0]
assert "G5: span inside div" {[dict get $firstSpan type] eq "span"}
assert "G6: span class cmd" {[dict get $firstSpan class] eq "cmd"}

# =========================================================================
# H: Fenced Divs -- Mehrere Bloecke
# =========================================================================

set md {::: {.example}
# Heading Inside

Some text.

```tcl
puts "hi"
```
:::
}

set ast [mdparser::parse $md]
set div [lindex [dict get $ast blocks] 0]
assert "H1: div type" {[dict get $div type] eq "div"}
set inner [dict get $div blocks]
assert "H2: heading inside" {[dict get [lindex $inner 0] type] eq "heading"}
assert "H3: paragraph inside" {[dict get [lindex $inner 1] type] eq "paragraph"}
assert "H4: code_block inside" {[dict get [lindex $inner 2] type] eq "code_block"}

# =========================================================================
# I: Fenced divs -- nested
# =========================================================================

set md {::: {.outer}
Text outer.

::: {.inner}
Text inner.
:::
:::
}

set ast [mdparser::parse $md]
set outerDiv [lindex [dict get $ast blocks] 0]
assert "I1: outer div" {[dict get $outerDiv type] eq "div"}
assert "I2: outer class" {[dict get $outerDiv class] eq "outer"}

# Find inner div
set innerDiv ""
foreach b [dict get $outerDiv blocks] {
    if {[dict get $b type] eq "div"} { set innerDiv $b; break }
}
assert "I3: inner div found" {$innerDiv ne ""}
assert "I4: inner class" {[dict get $innerDiv class] eq "inner"}

# =========================================================================
# J: Fenced Divs -- Syntax-Varianten
# =========================================================================

# ::: .class (dot without braces)
set md {::: .note
Important text.
:::
}
set ast [mdparser::parse $md]
set div [lindex [dict get $ast blocks] 0]
assert "J1: dot-class syntax" {[dict get $div type] eq "div"}
assert "J2: class from dot syntax" {[dict get $div class] eq "note"}

# ::: class (bare word)
set md {::: warning
Be careful.
:::
}
set ast [mdparser::parse $md]
set div [lindex [dict get $ast blocks] 0]
assert "J3: bare class syntax" {[dict get $div type] eq "div"}
assert "J4: class from bare syntax" {[dict get $div class] eq "warning"}

# =========================================================================
# K: Fenced Divs -- Leerer Div
# =========================================================================

set md {::: {.empty}
:::
}
set ast [mdparser::parse $md]
set div [lindex [dict get $ast blocks] 0]
assert "K1: empty div type" {[dict get $div type] eq "div"}
assert "K2: empty div no blocks" {[llength [dict get $div blocks]] == 0}

# =========================================================================
# L: Bare ::: wird uebersprungen
# =========================================================================

set md {Some text.

:::

More text.
}
set ast [mdparser::parse $md]
set blocks [dict get $ast blocks]
# Should have 2 paragraphs, ::: is skipped
set types {}
foreach b $blocks {
    lappend types [dict get $b type]
}
assert "L1: bare ::: skipped" {"div" ni $types}
assert "L2: two paragraphs" {[llength [lsearch -all $types "paragraph"]] == 2}

# =========================================================================
# M: Kombination YAML + Div
# =========================================================================

set md {---
title: test
---

::: {.synopsis}
[test]{.cmd} [arg]{.arg}
:::

Description paragraph.
}
set ast [mdparser::parse $md]
assert "M1: meta present" {[dict get [dict get $ast meta] title] eq "test"}
set blocks [dict get $ast blocks]
assert "M2: div block" {[dict get [lindex $blocks 0] type] eq "div"}
assert "M3: paragraph after div" {[dict get [lindex $blocks 1] type] eq "paragraph"}

# =========================================================================
puts ""
puts "=== parser-tip700-t2t3.tcl ==="
puts "$passed/$total passed, $failed failed"
