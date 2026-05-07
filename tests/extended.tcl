#!/usr/bin/env tclsh
# extended.tcl - Tests for extended mdparser Features
# Tables, blockquotes, images, task lists

# Eigene Module aus dem Repo (Tests laufen aus dem Repo)
if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}


package require tcltest
namespace import ::tcltest::*

package require mdstack::parser 0.2

# --- Tables ---

test table-1 "parse simple table" -body {
    set md {| A | B |
|---|---|
| 1 | 2 |
}
    set ast [mdstack::parser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block type
} -result {table}

test table-2 "table header cells" -body {
    set md {| Name | Wert |
|------|------|
| X | Y |
}
    set ast [mdstack::parser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    # Seit A.3 Lesart 2: table.content ist Liste von tableRow-Knoten,
    # erste Zeile ist der Header (wenn meta.hasHeader=1), Cells sind
    # tableCell-Knoten mit Inline-Listen.
    set headerRow [lindex [dict get $block content] 0]
    set headerTexts {}
    foreach cell [dict get $headerRow content] {
        set inlines [dict get $cell content]
        # Plain-Text aus Inlines: Konkatenation aller value-Felder (mdparser-Inlines)
        set t ""
        foreach inl $inlines {
            if {[dict exists $inl value]} { append t [dict get $inl value] }
        }
        lappend headerTexts $t
    }
    set headerTexts
} -result {Name Wert}

test table-3 "table alignments" -body {
    set md {| Left | Center | Right |
|:-----|:------:|------:|
| a | b | c |
}
    set ast [mdstack::parser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    # Seit A.3 Lesart 2: alignments leben in meta
    dict get [dict get $block meta] alignments
} -result {left center right}

test table-4 "table body rows" -body {
    set md {| A | B |
|---|---|
| 1 | 2 |
| 3 | 4 |
}
    set ast [mdstack::parser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    # Seit A.3 Lesart 2: content enthält Header-Row + Body-Rows.
    # Body-Rows = total - 1 wenn hasHeader, sonst total.
    set rowCount [llength [dict get $block content]]
    set hasHeader [dict get [dict get $block meta] hasHeader]
    expr {$rowCount - $hasHeader}
} -result {2}

# --- Blockquotes ---

test blockquote-1 "parse simple blockquote" -body {
    set md {> This is a quote.
}
    set ast [mdstack::parser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block type
} -result {blockquote}

test blockquote-2 "blockquote has blocks (recursive AST)" -body {
    set md {> Quote text here.
}
    set ast [mdstack::parser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    expr {[llength [dict get $block blocks]] > 0}
} -result {1}

test blockquote-3 "multiline blockquote" -body {
    set md {> Line one.
> Line two.
}
    set ast [mdstack::parser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block type
} -result {blockquote}

# --- Standalone Images ---

test image-1 "parse standalone image" -body {
    set md {![Alt text](image.png)
}
    set ast [mdstack::parser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block type
} -result {image}

test image-2 "image alt text" -body {
    set md {![My Alt](pic.jpg)
}
    set ast [mdstack::parser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block alt
} -result {My Alt}

test image-3 "image url" -body {
    set md {![Alt](images/photo.png)
}
    set ast [mdstack::parser::parse $md]
    set block [lindex [dict get $ast blocks] 0]
    dict get $block url
} -result {images/photo.png}

# --- Inline Images ---

test inline-image-1 "parse inline image" -body {
    set md {Text with ![icon](icon.png) in middle.}
    set ast [mdstack::parser::parse $md]
    set para [lindex [dict get $ast blocks] 0]
    set hasImage 0
    foreach inline [dict get $para content] {
        if {[dict get $inline type] eq "image"} {
            set hasImage 1
            break
        }
    }
    set hasImage
} -result {1}

# --- Task Lists ---

test tasklist-1 "parse unchecked task" -body {
    set md {- [ ] Task one
}
    set ast [mdstack::parser::parse $md]
    set list [lindex [dict get $ast blocks] 0]
    set item [lindex [dict get $list items] 0]
    dict get $item checked
} -result {0}

test tasklist-2 "parse checked task" -body {
    set md {- [x] Task done
}
    set ast [mdstack::parser::parse $md]
    set list [lindex [dict get $ast blocks] 0]
    set item [lindex [dict get $list items] 0]
    dict get $item checked
} -result {1}

test tasklist-3 "mixed task list" -body {
    set md {- [ ] Open
- [x] Done
- [ ] Open
}
    set ast [mdstack::parser::parse $md]
    set list [lindex [dict get $ast blocks] 0]
    set checked 0
    foreach item [dict get $list items] {
        if {[dict exists $item checked] && [dict get $item checked]} {
            incr checked
        }
    }
    set checked
} -result {1}

# --- supports ---

test supports-1 "supports table" -body {
    expr {"blocks:table" in [mdstack::parser::supports {}]}
} -result {1}

test supports-2 "supports blockquote" -body {
    expr {"blocks:blockquote" in [mdstack::parser::supports {}]}
} -result {1}

test supports-3 "supports image" -body {
    expr {"blocks:image" in [mdstack::parser::supports {}]}
} -result {1}

test supports-4 "supports inline image" -body {
    expr {"inline:image" in [mdstack::parser::supports {}]}
} -result {1}

cleanupTests
