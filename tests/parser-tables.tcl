#!/usr/bin/env tclsh
# parser-tables.tcl - GFM tables: cell splitting, escaped pipes, alignment

if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}
package require tcltest
namespace import ::tcltest::*
package require mdstack::parser

# Cells of one raw row line.
proc row {line} {
    return [mdstack::parser::parseTableRow $line]
}

# Cell texts of the first table in a document: {r1c1 r1c2 ... } per row.
proc tableCellTexts {md} {
    set ast [dict get [mdstack::parser::parse $md] blocks]
    foreach node $ast {
        if {[dict get $node type] ne "table"} { continue }
        set out {}
        foreach r [dict get $node content] {
            set cells {}
            foreach c [dict get $r content] {
                set txt ""
                foreach inl [dict get $c content] {
                    switch -- [dict get $inl type] {
                        text        { append txt [dict get $inl value] }
                        inline_code { append txt "<code>[dict get $inl value]</code>" }
                        default     { append txt [dict get $inl value] }
                    }
                }
                lappend cells $txt
            }
            lappend out $cells
        }
        return $out
    }
    return "NOTABLE"
}

# --- cell splitting ---------------------------------------------------------

test tbl-split-basic {plain row splits on pipes} -body {
    row {| a | b | c |}
} -result {a b c}

test tbl-split-no-outer-pipes {row without outer pipes} -body {
    row {a | b}
} -result {a b}

test tbl-split-empty-cell {empty cell is kept} -body {
    row {| a |  | c |}
} -result {a {} c}

# --- escaped pipes (the bug) ------------------------------------------------

test tbl-escaped-pipe {a backslash-pipe is a literal pipe, not a delimiter} -body {
    row {| a \| b | c |}
} -result {{a | b} c}

test tbl-escaped-pipe-count {escaped pipe does not create a column} -body {
    llength [row {| a \| b | c |}]
} -result 2

test tbl-escaped-pipe-trailing {row ending in an escaped pipe keeps it} -body {
    row {| a | b \|}
} -result {a {b |}}

test tbl-escaped-backslash {an escaped backslash stays; the pipe after it splits} -body {
    row {| a \\ | b |}
} -result {{a \\} b}

test tbl-other-escape-untouched {other backslash escapes are left for the inline parser} -body {
    row {| a \* b | c |}
} -result {{a \* b} c}

test tbl-multiple-escapes {several escaped pipes in one cell} -body {
    row {| a \| b \| c | d |}
} -result {{a | b | c} d}

# --- escaped pipes end-to-end ----------------------------------------------

test tbl-doc-escaped-pipe {escaped pipe survives into the cell text} -body {
    tableCellTexts "| A | B |\n|---|---|\n| x \\| y | z |\n"
} -result {{A B} {{x | y} z}}

test tbl-doc-column-count {the escaped pipe does not add a column} -body {
    set ast [dict get [mdstack::parser::parse "| A | B |\n|---|---|\n| x \\| y | z |\n"] blocks]
    dict get [lindex $ast 0] meta columns
} -result 2

test tbl-doc-code-span-pipe {a pipe inside a code span, escaped as GFM requires} -body {
    tableCellTexts "| A | B |\n|---|---|\n| `a \\| b` | z |\n"
} -result {{A B} {{<code>a | b</code>} z}}

# --- alignment row ----------------------------------------------------------

test tbl-align {alignment row is parsed through the same splitter} -body {
    set ast [dict get [mdstack::parser::parse "| A | B | C |\n|:--|:-:|--:|\n| 1 | 2 | 3 |\n"] blocks]
    dict get [lindex $ast 0] meta alignments
} -result {left center right}

cleanupTests
