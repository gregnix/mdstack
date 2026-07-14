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

package require mdstack::parser 0.2

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

# Since 0.7.0 adjacent text nodes are merged, so an escaped run is ONE text
# node instead of four ("no ", "*", "bold", "*", " here"). What matters is that
# no emphasis is produced and the stars survive literally.
set r [mdstack::parser::parseInlines {no \*bold\* here}]
assert "escape-star: one text node" {[llength $r] == 1}
assert "escape-star: no emphasis" {[itype $r 0] eq "text"}
assert "escape-star: stars literal" {[itext $r 0] eq {no *bold* here}}

set r [mdstack::parser::parseInlines {no \`code\` here}]
assert "escape-backtick: no code span" {[llength $r] == 1 && [itype $r 0] eq "text"}
assert "escape-backtick: backticks literal" {[itext $r 0] eq {no `code` here}}

set r [mdstack::parser::parseInlines {no \~\~strike\~\~ here}]
assert "escape-tilde: no strike" {[llength $r] == 1 && [itype $r 0] eq "text"}
assert "escape-tilde: tildes literal" {[itext $r 0] eq {no ~~strike~~ here}}

set r [mdstack::parser::parseInlines {use \[not a link\]}]
assert "escape-bracket: no link" {[llength $r] == 1 && [itype $r 0] eq "text"}
assert "escape-bracket: brackets literal" {[itext $r 0] eq {use [not a link]}}

set r [mdstack::parser::parseInlines "backslash: \\\\done"]
assert "escape-backslash: literal backslash" {[llength $r] == 1 && [itype $r 0] eq "text"}
assert "escape-backslash: text merged" {[itext $r 0] eq "backslash: \\done"}

# Nicht-Escape: normaler Backslash vor nicht-speziellem Zeichen
set r [mdstack::parser::parseInlines {path\nhere}]
# \n ist kein Escape-Zeichen -> der Backslash bleibt literal im Text stehen
# (seit 0.7.0 in EINEM Textknoten, weil benachbarte Textknoten verschmolzen werden)
assert "non-escape: backslash as text" {[llength $r] == 1 && [itype $r 0] eq "text"}
assert "non-escape: backslash literal" {[itext $r 0] eq {path\nhere}}

# ============================================================
# BUG2: Bold+Italic (***)
#
# Nesting order changed with the delimiter stack (parser 0.7.0): CommonMark
# resolves *** as <em><strong>x</strong></em> -- the two-delimiter (strong)
# pair is consumed first, the leftover single pair wraps it. The old scanner
# produced strong[emphasis[...]]. Both render bold+italic; the CommonMark order
# is now the reference.
# ============================================================

set r [mdstack::parser::parseInlines {***bold and italic***}]
assert "bolditalic: one element" {[llength $r] == 1}
assert "bolditalic: outer is em" {[itype $r 0] eq "emphasis"}
set inner [dict get [lindex $r 0] content]
assert "bolditalic: inner is strong" {[dict get [lindex $inner 0] type] eq "strong"}
set stInner [dict get [lindex $inner 0] content]
assert "bolditalic: text correct" {[dict get [lindex $stInner 0] value] eq "bold and italic"}

set r [mdstack::parser::parseInlines {before ***combo*** after}]
assert "bolditalic-context: 3 elements" {[llength $r] == 3}
assert "bolditalic-context: middle is em" {[itype $r 1] eq "emphasis"}

# ============================================================
# BUG3: Double-Backtick Code
# ============================================================

set r [mdstack::parser::parseInlines {use ``code `with` ticks`` here}]
assert "dbl-backtick: 3 elements" {[llength $r] == 3}
assert "dbl-backtick: middle is code" {[itype $r 1] eq "inline_code"}
assert "dbl-backtick: preserves inner backticks" {[itext $r 1] eq "code `with` ticks"}

set r [mdstack::parser::parseInlines {``single``}]
assert "dbl-backtick-simple: is code" {[itype $r 0] eq "inline_code"}
assert "dbl-backtick-simple: text" {[itext $r 0] eq "single"}

# Ungeschlossene double-backticks → als Text
set r [mdstack::parser::parseInlines {``unclosed here}]
assert "dbl-backtick-unclosed: fallback to text" {[itype $r 0] eq "text"}

# ============================================================
# BUG4: Link/Image Title
# ============================================================

set r [mdstack::parser::parseInlines {[Tcl](https://tcl.tk "Homepage")}]
assert "link-title: is link" {[itype $r 0] eq "link"}
assert "link-title: url clean" {[dict get [lindex $r 0] url] eq "https://tcl.tk"}
assert "link-title: title parsed" {[dict get [lindex $r 0] title] eq "Homepage"}

set r [mdstack::parser::parseInlines {[Tcl](https://tcl.tk)}]
assert "link-no-title: url clean" {[dict get [lindex $r 0] url] eq "https://tcl.tk"}
assert "link-no-title: no title key" {![dict exists [lindex $r 0] title]}

set r [mdstack::parser::parseInlines {![Image](img.png "Description")}]
assert "image-title: is image" {[itype $r 0] eq "image"}
assert "image-title: url clean" {[dict get [lindex $r 0] url] eq "img.png"}
assert "image-title: title parsed" {[dict get [lindex $r 0] title] eq "Description"}
assert "image-title: no trailing junk" {[llength $r] == 1}

set r [mdstack::parser::parseInlines {![Alt](image.png)}]
assert "image-no-title: url clean" {[dict get [lindex $r 0] url] eq "image.png"}
assert "image-no-title: no trailing junk" {[llength $r] == 1}

# ============================================================
# Regression: existing features unchanged
# ============================================================

set r [mdstack::parser::parseInlines {text **bold** text}]
assert "reg-bold: strong" {[itype $r 1] eq "strong"}

set r [mdstack::parser::parseInlines {text *italic* text}]
assert "reg-italic: em" {[itype $r 1] eq "emphasis"}

set r [mdstack::parser::parseInlines {text `code` text}]
assert "reg-code: code_inline" {[itype $r 1] eq "inline_code"}

set r [mdstack::parser::parseInlines {text ~~strike~~ text}]
assert "reg-strike: strike" {[itype $r 1] eq "strike"}

set r [mdstack::parser::parseInlines {**first** and **second**}]
assert "reg-multi-bold: two strong" {[itype $r 0] eq "strong" && [itype $r 2] eq "strong"}

set r [mdstack::parser::parseInlines {**bold with `code` inside**}]
assert "reg-nested: strong with code" {[itype $r 0] eq "strong"}
set si [dict get [lindex $r 0] content]
assert "reg-nested: inner code" {[dict get [lindex $si 1] type] eq "inline_code"}

set r [mdstack::parser::parseInlines {[Link](https://example.com)}]
assert "reg-link: link" {[itype $r 0] eq "link"}
assert "reg-link: url" {[dict get [lindex $r 0] url] eq "https://example.com"}

# ============================================================
# Result
# ============================================================

puts "$script:\tTotal\t$total\tPassed\t$passed\tSkipped\t0\tFailed\t$failed"
