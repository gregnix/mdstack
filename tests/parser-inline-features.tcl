#!/usr/bin/env tclsh
# ============================================================
# Tests for fehlende Inline-Features
# ============================================================
# Feature 1: Bare URL + Angle-Bracket Autolinks
# Feature 2: Heading Inline-Parsing
# Feature 3: table cell inline parsing

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

proc itype {inlines n} { dict get [lindex $inlines $n] type }
proc itext {inlines n} { dict get [lindex $inlines $n] value }
proc labelText {node} {
    set txt ""
    foreach i [dict get $node label] {
        if {[dict get $i type] eq "text"} { append txt [dict get $i value] }
    }
    return $txt
}

# ============================================================
# Feature 1: Bare URL Autolinks
# ============================================================

set r [mdparser::parseInlines {visit https://example.com today}]
assert "bare-url: text before" {[itype $r 0] eq "text" && [itext $r 0] eq "visit "}
assert "bare-url: link type" {[itype $r 1] eq "link"}
assert "bare-url: url" {[dict get [lindex $r 1] url] eq "https://example.com"}
assert "bare-url: text after" {[itype $r 2] eq "text" && [itext $r 2] eq " today"}

set r [mdparser::parseInlines {see https://example.com/path?q=1#frag here}]
assert "bare-url-complex: link" {[itype $r 1] eq "link"}
assert "bare-url-complex: full url" {[dict get [lindex $r 1] url] eq "https://example.com/path?q=1#frag"}

set r [mdparser::parseInlines {link: https://tcl.tk}]
assert "bare-url-end: link at end" {[itype $r 1] eq "link"}

set r [mdparser::parseInlines {Infos auf https://wiki.tcl-lang.org.}]
assert "bare-url-trailing-dot: dot stripped" {[dict get [lindex $r 1] url] eq "https://wiki.tcl-lang.org"}

set r [mdparser::parseInlines {http://example.com works too}]
assert "bare-url-http: http works" {[itype $r 0] eq "link"}

set r [mdparser::parseInlines {see https://a.com and https://b.com here}]
assert "bare-url-two: first link" {[itype $r 1] eq "link" && [dict get [lindex $r 1] url] eq "https://a.com"}
assert "bare-url-two: second link" {[itype $r 3] eq "link" && [dict get [lindex $r 3] url] eq "https://b.com"}

# Angle-Bracket Autolinks
set r [mdparser::parseInlines {visit <https://example.com> here}]
assert "angle-url: link" {[itype $r 1] eq "link"}
assert "angle-url: url" {[dict get [lindex $r 1] url] eq "https://example.com"}
assert "angle-url: text is url" {[labelText [lindex $r 1]] eq "https://example.com"}

set r [mdparser::parseInlines {mail <user@example.com> bitte}]
assert "angle-mailto: link" {[itype $r 1] eq "link"}
assert "angle-mailto: mailto url" {[dict get [lindex $r 1] url] eq "mailto:user@example.com"}
assert "angle-mailto: text is email" {[labelText [lindex $r 1]] eq "user@example.com"}

# Markdown-Links haben Vorrang
set r [mdparser::parseInlines {use [Tcl](https://tcl.tk) here}]
assert "mdlink-priority: is link" {[itype $r 1] eq "link"}
assert "mdlink-priority: text is label" {[labelText [lindex $r 1]] eq "Tcl"}

# Kein falscher Autolink
set r [mdparser::parseInlines {just http text here}]
assert "no-false-autolink: all text" {[itype $r 0] eq "text"}

# ============================================================
# Feature 2: Heading Inline-Parsing
# ============================================================

set ast [mdparser::parse "## Title mit **bold** und `code`"]
set b [lindex [dict get $ast blocks] 0]
assert "heading-inlines: has inlines" {[dict exists $b content]}
set inl [dict get $b content]
assert "heading-inlines: text before" {[itype $inl 0] eq "text" && [itext $inl 0] eq "Title mit "}
assert "heading-inlines: strong" {[itype $inl 1] eq "strong"}
assert "heading-inlines: text mid" {[itype $inl 2] eq "text"}
assert "heading-inlines: code" {[itype $inl 3] eq "inline_code"}
assert "heading-inlines: anchor preserved" {[dict get $b anchor] eq "title-mit-bold-und-code"}

# Heading without formatting
set ast [mdparser::parse "# Plain Title"]
set b [lindex [dict get $ast blocks] 0]
assert "heading-plain: has inlines" {[dict exists $b content]}
set inl [dict get $b content]
assert "heading-plain: single text" {[llength $inl] == 1 && [itype $inl 0] eq "text"}

# Heading mit Link
set ast [mdparser::parse {### See [Docs](https://docs.com)}]
set b [lindex [dict get $ast blocks] 0]
set inl [dict get $b content]
assert "heading-link: has link inline" {[itype $inl 1] eq "link"}

# ============================================================
# Feature 3: table cell inline parsing
# ============================================================

set md {| **Bold** | `Code` | Normal |
|---|---|---|
| *Italic* | ~~Strike~~ | Text |}
set ast [mdparser::parse $md]
set b [lindex [dict get $ast blocks] 0]

assert "table: has headerInlines" {[dict exists $b headerInlines]}
assert "table: has rowsInlines" {[dict exists $b rowsInlines]}

# Header-Zellen
set hI [dict get $b headerInlines]
assert "table-header: 3 cells" {[llength $hI] == 3}
assert "table-header-0: strong" {[dict get [lindex [lindex $hI 0] 0] type] eq "strong"}
assert "table-header-1: code" {[dict get [lindex [lindex $hI 1] 0] type] eq "inline_code"}
assert "table-header-2: text" {[dict get [lindex [lindex $hI 2] 0] type] eq "text"}

# Body-Zellen
set rI [dict get $b rowsInlines]
assert "table-row: 1 row" {[llength $rI] == 1}
set row0 [lindex $rI 0]
assert "table-row-0: 3 cells" {[llength $row0] == 3}
assert "table-cell-0-0: em" {[dict get [lindex [lindex $row0 0] 0] type] eq "emphasis"}
assert "table-cell-0-1: strike" {[dict get [lindex [lindex $row0 1] 0] type] eq "strike"}
assert "table-cell-0-2: text" {[dict get [lindex [lindex $row0 2] 0] type] eq "text"}

# Backward compatibility: header und rows weiterhin als raw strings
assert "table-compat: header is strings" {[lindex [dict get $b header] 0] eq "**Bold**"}
assert "table-compat: rows is strings" {[lindex [lindex [dict get $b rows] 0] 0] eq "*Italic*"}

# Table with links
set md2 {| Link |
|---|
| [Tcl](https://tcl.tk) |}
set ast2 [mdparser::parse $md2]
set b2 [lindex [dict get $ast2 blocks] 0]
set rI2 [dict get $b2 rowsInlines]
assert "table-link: cell has link" {[dict get [lindex [lindex [lindex $rI2 0] 0] 0] type] eq "link"}

# Table with mixed content
set md3 {| A | B |
|---|---|
| **bold** und `code` | normal |}
set ast3 [mdparser::parse $md3]
set b3 [lindex [dict get $ast3 blocks] 0]
set rI3 [dict get $b3 rowsInlines]
set cell [lindex [lindex $rI3 0] 0]
assert "table-mixed: multiple inlines" {[llength $cell] >= 3}
assert "table-mixed: has strong" {[dict get [lindex $cell 0] type] eq "strong"}
assert "table-mixed: has code" {[dict get [lindex $cell 2] type] eq "inline_code"}

# ============================================================
# Result
# ============================================================

puts "$script:\tTotal\t$total\tPassed\t$passed\tSkipped\t0\tFailed\t$failed"
