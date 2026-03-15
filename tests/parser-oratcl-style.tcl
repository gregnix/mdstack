#!/usr/bin/env tclsh
# parser-oratcl-style.tcl - Realworld test with man-page style documents

package require tcltest
namespace import ::tcltest::*

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require mdparser 0.2

# ============================================================
# Simulate oratcl.md structure: headings + indented content
# ============================================================

test oratcl-structure-1 "typical man-page: heading + indented description" -body {
    set md {## NAME

    oratcl - Tcl interface to Oracle databases

## SYNOPSIS

    package require Oratcl
    package require -exact Oratcl 4.6

## DESCRIPTION

    Oratcl is an extension to the Tcl language designed to
    provide access to an Oracle Database Server. Each Oratcl
    command generally invokes several Oracle Call Interface
    library functions.

## COMMANDS

    oralogon
        Logs onto the Oracle server, returning a handle.

        Example:
            set lda [oralogon user/pass@db]

    oralogoff
        Disconnects from the Oracle server.
}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    set types {}
    foreach b $blocks {
        lappend types [dict get $b type]
    }
    set types
} -result {heading code_block heading code_block heading code_block heading code_block}

test oratcl-structure-2 "indented text preserves internal structure" -body {
    set md {## COMMANDS

    oralogon
        Logs onto the Oracle server.

        Example:
            set lda [oralogon user/pass@db]
}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    set codeBlock [lindex $blocks 1]
    set text [dict get $codeBlock text]
    # Verify line count (5 content lines + 1 blank line = preserved)
    set lines [split $text "\n"]
    # oralogon / (4 spaces)Logs... / (blank) / (4 spaces)Example: / (8 spaces)set lda...
    expr {[llength $lines] >= 5}
} -result {1}

test oratcl-structure-3 "8-space indent becomes 4-space in output" -body {
    set md {## EXAMPLE

        package require Oratcl 4.6
        set lda [oralogon scott/tiger@orcl]
}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    set codeBlock [lindex $blocks 1]
    set firstLine [lindex [split [dict get $codeBlock text] "\n"] 0]
    # 8 spaces original - 4 stripped = 4 remaining
    string range $firstLine 0 3
} -result {    }

test oratcl-block-count "large document produces correct block count" -body {
    set md {## SECTION A

    Content of section A line 1
    Content of section A line 2

## SECTION B

    Content of section B line 1
    Content of section B line 2
    Content of section B line 3

## SECTION C

    Content of section C line 1
}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    # 3 headings + 3 code blocks = 6
    llength $blocks
} -result {6}

test oratcl-no-paragraph-merging "indented lines NOT merged into single paragraph" -body {
    # This was the old (broken) behavior: everything became one long paragraph
    set md {## DESC

    Line one of description.
    Line two of description.
    Line three of description.
}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    set second [lindex $blocks 1]
    # Must be code, NOT paragraph
    dict get $second type
} -result {code_block}

test oratcl-linebreaks-preserved "line breaks within indented code preserved" -body {
    set md {## NOTES

    This is a note that spans
    multiple lines and should
    keep its line structure.
}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 1]
    set text [dict get $block text]
    set lines [split $text "\n"]
    llength $lines
} -result {3}

# ============================================================
# Comparison: old vs new behavior
# ============================================================

test old-vs-new-1 "fenced code blocks still work unchanged" -body {
    set md {```tcl
package require Oratcl
set lda [oralogon scott/tiger]
```}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    list [dict get $block type] [dict get $block language]
} -result {code_block tcl}

test old-vs-new-2 "normal paragraphs still work" -body {
    set md {This is a normal paragraph with no special indentation.
It continues on the next line.}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block type
} -result {paragraph}

test old-vs-new-3 "tables still parsed correctly" -body {
    set md {| Command | Description |
|---------|-------------|
| oralogon | Connect to Oracle |
| oralogoff | Disconnect |
}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block type
} -result {table}

cleanupTests
