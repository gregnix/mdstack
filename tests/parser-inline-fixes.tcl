#!/usr/bin/env tclsh
# ============================================================
# Regression tests for Inline-Parser Bugfixes
# ============================================================
# BUG1: Backslash-Escape (\* \` \~ etc.)
# BUG2: Bold+Italic (***text***)
# BUG3: Double-Backtick Code (``code `x` ``)
# BUG4: Link/Image Title ([t](url "title"))

set dir [file dirname [file normalize [info script]]]
tcl::tm::path add [file join $dir .. lib]

package require mdparser 0.2

set passed 0
set failed 0
set total 0
set script [file tail [info script]]

proc assert {label condition} {
    upvar passed passed failed failed total total script script
    incr total
    if {[uplevel 1 [list expr $condition]]} {
        incr passed
    } else {
        incr failed
        puts "  FAIL: $label"
    }
}

# Helper: returns type of first/nth inline element
proc itype {inlines n} {
    return [dict get [lindex $inlines $n] type]
}
proc itext {inlines n} {
    return [dict get [lindex $inlines $n] value]
}

# ============================================================
# BUG1: Backslash-Escape
# ============================================================

set r [mdparser::parseInlines {no \*bold\* here}]
assert "escape-star: no emphasis" {[itype $r 1] eq "text" && [itext $r 1] eq "*"}
assert "escape-star: plain bold text" {[itype $r 2] eq "text" && [itext $r 2] eq "bold"}
assert "escape-star: closing star literal" {[itype $r 3] eq "text" && [itext $r 3] eq "*"}

set r [mdparser::parseInlines {no \`code\` here}]
assert "escape-backtick: no code span" {[itype $r 1] eq "text" && [itext $r 1] eq "`"}

set r [mdparser::parseInlines {no \~\~strike\~\~ here}]
assert "escape-tilde: no strike" {[itype $r 1] eq "text" && [itext $r 1] eq "~"}

set r [mdparser::parseInlines {use \[not a link\]}]
assert "escape-bracket: no link" {[itype $r 1] eq "text" && [itext $r 1] eq {[}}

set r [mdparser::parseInlines "backslash: \\\\done"]
set expected "\\"
assert "escape-backslash: literal backslash" {[itype $r 1] eq "text" && [itext $r 1] eq $expected}

# Nicht-Escape: normaler Backslash vor nicht-speziellem Zeichen
set r [mdparser::parseInlines {path\nhere}]
# \n ist kein Escape-Zeichen → \ wird als eigenes Text-Element ausgegeben
assert "non-escape: backslash as text" {[itype $r 1] eq "text" && [itext $r 1] eq "\\"}

# ============================================================
# BUG2: Bold+Italic (***)
# ============================================================

set r [mdparser::parseInlines {***bold and italic***}]
assert "bolditalic: one element" {[llength $r] == 1}
assert "bolditalic: outer is strong" {[itype $r 0] eq "strong"}
set inner [dict get [lindex $r 0] content]
assert "bolditalic: inner is em" {[dict get [lindex $inner 0] type] eq "emphasis"}
set emInner [dict get [lindex $inner 0] content]
assert "bolditalic: em text correct" {[dict get [lindex $emInner 0] value] eq "bold and italic"}

set r [mdparser::parseInlines {before ***combo*** after}]
assert "bolditalic-context: 3 elements" {[llength $r] == 3}
assert "bolditalic-context: middle is strong" {[itype $r 1] eq "strong"}

# ============================================================
# BUG3: Double-Backtick Code
# ============================================================

set r [mdparser::parseInlines {use ``code `with` ticks`` here}]
assert "dbl-backtick: 3 elements" {[llength $r] == 3}
assert "dbl-backtick: middle is code" {[itype $r 1] eq "inline_code"}
assert "dbl-backtick: preserves inner backticks" {[itext $r 1] eq "code `with` ticks"}

set r [mdparser::parseInlines {``single``}]
assert "dbl-backtick-simple: is code" {[itype $r 0] eq "inline_code"}
assert "dbl-backtick-simple: text" {[itext $r 0] eq "single"}

# Ungeschlossene double-backticks → als Text
set r [mdparser::parseInlines {``unclosed here}]
assert "dbl-backtick-unclosed: fallback to text" {[itype $r 0] eq "text"}

# ============================================================
# BUG4: Link/Image Title
# ============================================================

set r [mdparser::parseInlines {[Tcl](https://tcl.tk "Homepage")}]
assert "link-title: is link" {[itype $r 0] eq "link"}
assert "link-title: url clean" {[dict get [lindex $r 0] url] eq "https://tcl.tk"}
assert "link-title: title parsed" {[dict get [lindex $r 0] title] eq "Homepage"}

set r [mdparser::parseInlines {[Tcl](https://tcl.tk)}]
assert "link-no-title: url clean" {[dict get [lindex $r 0] url] eq "https://tcl.tk"}
assert "link-no-title: no title key" {![dict exists [lindex $r 0] title]}

set r [mdparser::parseInlines {![Image](img.png "Description")}]
assert "image-title: is image" {[itype $r 0] eq "image"}
assert "image-title: url clean" {[dict get [lindex $r 0] url] eq "img.png"}
assert "image-title: title parsed" {[dict get [lindex $r 0] title] eq "Description"}
assert "image-title: no trailing junk" {[llength $r] == 1}

set r [mdparser::parseInlines {![Alt](image.png)}]
assert "image-no-title: url clean" {[dict get [lindex $r 0] url] eq "image.png"}
assert "image-no-title: no trailing junk" {[llength $r] == 1}

# ============================================================
# Regression: existing features unchanged
# ============================================================

set r [mdparser::parseInlines {text **bold** text}]
assert "reg-bold: strong" {[itype $r 1] eq "strong"}

set r [mdparser::parseInlines {text *italic* text}]
assert "reg-italic: em" {[itype $r 1] eq "emphasis"}

set r [mdparser::parseInlines {text `code` text}]
assert "reg-code: code_inline" {[itype $r 1] eq "inline_code"}

set r [mdparser::parseInlines {text ~~strike~~ text}]
assert "reg-strike: strike" {[itype $r 1] eq "strike"}

set r [mdparser::parseInlines {**first** and **second**}]
assert "reg-multi-bold: two strong" {[itype $r 0] eq "strong" && [itype $r 2] eq "strong"}

set r [mdparser::parseInlines {**bold with `code` inside**}]
assert "reg-nested: strong with code" {[itype $r 0] eq "strong"}
set si [dict get [lindex $r 0] content]
assert "reg-nested: inner code" {[dict get [lindex $si 1] type] eq "inline_code"}

set r [mdparser::parseInlines {[Link](https://example.com)}]
assert "reg-link: link" {[itype $r 0] eq "link"}
assert "reg-link: url" {[dict get [lindex $r 0] url] eq "https://example.com"}

# ============================================================
# Result
# ============================================================

puts "$script:\tTotal\t$total\tPassed\t$passed\tSkipped\t0\tFailed\t$failed"
