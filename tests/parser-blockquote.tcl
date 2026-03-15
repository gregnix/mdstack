#!/usr/bin/env tclsh
# parser-blockquote.tcl - Tests for nested blockquote support (mdparser 0.2)

package require tcltest
namespace import ::tcltest::*

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require mdparser 0.2

# ============================================================
# Basic blockquote produces blocks (not inlines)
# ============================================================

test blockquote-basic-1 "blockquote has blocks key" -body {
    set md {> Hello world}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict exists $block blocks
} -result {1}

test blockquote-basic-2 "blockquote type is blockquote" -body {
    set md {> Hello world}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block type
} -result {blockquote}

test blockquote-basic-3 "blockquote inner content is paragraph" -body {
    set md {> Hello world}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    set inner [lindex [dict get $block blocks] 0]
    dict get $inner type
} -result {paragraph}

test blockquote-basic-4 "blockquote inner text correct" -body {
    set md {> Hello world}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    set inner [lindex [dict get $block blocks] 0]
    set inlines [dict get $inner content]
    set firstText ""
    foreach node $inlines {
        if {[dict get $node type] eq "text"} {
            append firstText [dict get $node value]
        }
    }
    set firstText
} -result {Hello world}

# ============================================================
# Multi-line blockquotes
# ============================================================

test blockquote-multi-1 "multi-line blockquote forms one block" -body {
    set md {> Line one
> Line two
> Line three}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    list [llength $blocks] [dict get [lindex $blocks 0] type]
} -result {1 blockquote}

test blockquote-multi-2 "multi-line blockquote: lines joined in paragraph" -body {
    set md {> Line one
> Line two}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    set innerBlocks [dict get $block blocks]
    # Should be one paragraph with joined text
    llength $innerBlocks
} -result {1}

# ============================================================
# Nested blockquotes (>> )
# ============================================================

test blockquote-nested-1 "nested blockquote detected" -body {
    set md {> Outer
>> Inner nested}
    set ast [mdparser::parse $md]
    set outer [lindex [dict get $ast blocks] 0]
    set outerBlocks [dict get $outer blocks]
    # Should contain a paragraph and a nested blockquote
    set types {}
    foreach b $outerBlocks {
        lappend types [dict get $b type]
    }
    expr {"blockquote" in $types}
} -result {1}

test blockquote-nested-2 "nested blockquote inner text" -body {
    set md {>> Deeply nested text}
    set ast [mdparser::parse $md]
    set outer [lindex [dict get $ast blocks] 0]
    set inner [lindex [dict get $outer blocks] 0]
    # The inner should be a blockquote
    dict get $inner type
} -result {blockquote}

# ============================================================
# Blockquote with multiple block types
# ============================================================

test blockquote-heading-1 "blockquote containing heading" -body {
    set md {> ## Section Title
> Some paragraph text.}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    set innerBlocks [dict get $block blocks]
    set types {}
    foreach b $innerBlocks {
        lappend types [dict get $b type]
    }
    set types
} -result {heading paragraph}

test blockquote-list-1 "blockquote containing list" -body {
    set md {> - Item one
> - Item two
> - Item three}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    set innerBlocks [dict get $block blocks]
    set inner [lindex $innerBlocks 0]
    dict get $inner type
} -result {list}

test blockquote-code-1 "blockquote containing fenced code" -body {
    set md {> ```tcl
> set x 1
> ```}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    set innerBlocks [dict get $block blocks]
    set inner [lindex $innerBlocks 0]
    dict get $inner type
} -result {code_block}

# ============================================================
# Blockquote with blank lines (paragraph separation)
# ============================================================

test blockquote-para-sep-1 "blockquote with blank line creates two paragraphs" -body {
    set md {> First paragraph.
>
> Second paragraph.}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    set innerBlocks [dict get $block blocks]
    llength $innerBlocks
} -result {2}

# ============================================================
# Blockquote ending
# ============================================================

test blockquote-end-1 "blockquote stops at non-quoted line" -body {
    set md {> Quoted text.

Normal paragraph.}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    list [llength $blocks] \
         [dict get [lindex $blocks 0] type] \
         [dict get [lindex $blocks 1] type]
} -result {2 blockquote paragraph}

test blockquote-end-2 "blockquotes with blank + continued > are one blockquote" -body {
    # Per CommonMark: > A / blank / > B is ONE blockquote with two inner paragraphs
    set md {> First quote.
>
> Second quote.}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    set bq [lindex $blocks 0]
    set innerBlocks [dict get $bq blocks]
    list [llength $blocks] [dict get $bq type] [llength $innerBlocks]
} -result {1 blockquote 2}

test blockquote-end-3 "truly separated blockquotes (no > on blank line)" -body {
    # Blank line WITHOUT > prefix separates into two blockquotes
    # only if next line after blank also lacks >... but if it has >,
    # the lookahead merges them. To get two separate blockquotes,
    # need a non-quote line between them.
    set md {> First quote.

Normal text.

> Second quote.}
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    list [llength $blocks] \
         [dict get [lindex $blocks 0] type] \
         [dict get [lindex $blocks 1] type] \
         [dict get [lindex $blocks 2] type]
} -result {3 blockquote paragraph blockquote}

# ============================================================
# Edge cases
# ============================================================

test blockquote-empty-1 "empty blockquote line" -body {
    set md {> }
    set ast [mdparser::parse $md]
    set blocks [dict get $ast blocks]
    llength $blocks
} -result {1}

test blockquote-inline-1 "blockquote with bold text" -body {
    set md {> This is **bold** text.}
    set ast [mdparser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    set inner [lindex [dict get $block blocks] 0]
    set inlines [dict get $inner content]
    set types {}
    foreach node $inlines {
        lappend types [dict get $node type]
    }
    expr {"strong" in $types}
} -result {1}

cleanupTests
