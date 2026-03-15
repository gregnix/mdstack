#!/usr/bin/env tclsh
# parser-indented.tcl - Tests for indented code block support (mdparser 0.2)

package require tcltest
namespace import ::tcltest::*

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require mdparser 0.2

# ============================================================
# Basic indented code block detection
# ============================================================

test indent-1 "4 spaces produce code block" -body {
    set md {
    hello world
}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block type
} -result {code_block}

test indent-2 "tab produces code block" -body {
    set md "
\thello world
"
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block type
} -result {code_block}

test indent-3 "indented code has empty lang" -body {
    set md {
    some code
}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block language
} -result {}

test indent-4 "indented code text has indentation stripped" -body {
    set md {
    hello world
}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block text
} -result {hello world}

test indent-5 "3 spaces is NOT code block (paragraph)" -body {
    set md {
   only three spaces
}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block type
} -result {paragraph}

# ============================================================
# Multi-line indented code blocks
# ============================================================

test indent-multi-1 "multiple indented lines form one block" -body {
    set md {
    line one
    line two
    line three
}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    list [llength $blocks] [dict get [lindex $blocks 0] type]
} -result {1 code_block}

test indent-multi-2 "multi-line code preserves all lines" -body {
    set md {
    line one
    line two
    line three
}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block text
} -result "line one\nline two\nline three"

test indent-multi-3 "varying indentation preserved (beyond 4 spaces)" -body {
    set md {
    level 1
        level 2
            level 3
}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block text
} -result "level 1\n    level 2\n        level 3"

# ============================================================
# Blank lines within indented code
# ============================================================

test indent-blank-1 "blank line within code block is preserved" -body {
    set md {
    line one

    line three
}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    # Should be one code block, not two
    list [llength $blocks] [dict get [lindex $blocks 0] type]
} -result {1 code_block}

test indent-blank-2 "blank line within code block text" -body {
    set md {
    line one

    line three
}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block text
} -result "line one\n\nline three"

test indent-blank-3 "trailing blank lines are stripped" -body {
    set md {
    code line

}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block text
} -result {code line}

test indent-blank-4 "multiple trailing blanks all stripped" -body {
    set md {
    code line



next paragraph
}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block text
} -result {code line}

# ============================================================
# Interaction with other block types
# ============================================================

test indent-heading-1 "heading before indented code" -body {
    set md {## Title

    code here
}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    list [dict get [lindex $blocks 0] type] [dict get [lindex $blocks 1] type]
} -result {heading code_block}

test indent-para-1 "paragraph before indented code (separated by blank)" -body {
    set md {Normal paragraph.

    indented code
}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    list [dict get [lindex $blocks 0] type] [dict get [lindex $blocks 1] type]
} -result {paragraph code_block}

test indent-para-2 "indented line within paragraph stays in paragraph" -body {
    # Per CommonMark: indented code cannot interrupt a paragraph
    set md {Start of paragraph
    still the paragraph}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    list [llength $blocks] [dict get [lindex $blocks 0] type]
} -result {1 paragraph}

test indent-fenced-1 "fenced code still works" -body {
    set md {```tcl
set x 1
```}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    list [dict get $block type] [dict get $block language]
} -result {code_block tcl}

test indent-after-code-1 "paragraph after indented code" -body {
    set md {
    code block

Back to normal text.
}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    list [dict get [lindex $blocks 0] type] [dict get [lindex $blocks 1] type]
} -result {code_block paragraph}

test indent-list-1 "list before indented code" -body {
    set md {- item one
- item two

    code block
}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    list [dict get [lindex $blocks 0] type] [dict get [lindex $blocks 1] type]
} -result {list code_block}

# ============================================================
# Real-world: oratcl.md style content
# ============================================================

test indent-oratcl-1 "man-page style indented description" -body {
    set md {## DESCRIPTION

    Oratcl is an extension to the Tcl language designed to
    provide access to an Oracle Database Server.
}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    list [dict get [lindex $blocks 0] type] [dict get [lindex $blocks 1] type]
} -result {heading code_block}

test indent-oratcl-2 "man-page indented code example (8+ spaces)" -body {
    set md {## EXAMPLE

        package require Oratcl
        package require -exact Oratcl 4.6
}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    set codeBlock [lindex $blocks 1]
    # 8 spaces - 4 stripped = 4 remaining
    dict get $codeBlock text
} -result "    package require Oratcl\n    package require -exact Oratcl 4.6"

test indent-oratcl-3 "multiple indented sections separated by headings" -body {
    set md {## SECTION ONE

    First indented block.

## SECTION TWO

    Second indented block.
}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    set types {}
    foreach b $blocks {
        lappend types [dict get $b type]
    }
    set types
} -result {heading code_block heading code_block}

# ============================================================
# Tab handling
# ============================================================

test indent-tab-1 "tab indent stripped correctly" -body {
    set md "\tcode with tab"
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block text
} -result {code with tab}

test indent-tab-2 "mixed tab and space blocks" -body {
    set md "\tline one\n    line two"
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    # Both lines should form one block (both are valid indentation)
    list [llength $blocks] [dict get [lindex $blocks 0] type]
} -result {1 code_block}

# ============================================================
# supports updated
# ============================================================

test supports-indented-1 "supports lists code_indented" -body {
    expr {"blocks:code_indented" in [mdparser::supports {}]}
} -result {1}

# ============================================================
# Edge cases
# ============================================================

test indent-edge-1 "only blank lines after indent (no real content)" -body {
    # 4 spaces followed by nothing meaningful - just whitespace
    set md "    \n    \n"
    set ast [mdparser::parse $md]
    llength [dict get $ast blocks]
} -result {0}

test indent-edge-2 "single indented line" -body {
    set md {    single line}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    list [dict get $block type] [dict get $block text]
} -result {code_block {single line}}

test indent-edge-3 "indented code block does not eat HR" -body {
    set md {
    code block

---
}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    list [dict get [lindex $blocks 0] type] [dict get [lindex $blocks 1] type]
} -result {code_block hr}

cleanupTests
