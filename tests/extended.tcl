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

# --- Setext-Headings (v0.2.10) ---

test setext-1 "Setext H1 with === underline" -body {
    set md "My Title\n========\n\nBody text."
    set ast [mdstack::parser::parse $md]
    set h [lindex [dict get $ast blocks] 0]
    list [dict get $h type] [dict get $h level]
} -result {heading 1}

test setext-2 "Setext H2 with --- underline" -body {
    set md "My Subtitle\n-----------\n\nBody."
    set ast [mdstack::parser::parse $md]
    set h [lindex [dict get $ast blocks] 0]
    list [dict get $h type] [dict get $h level]
} -result {heading 2}

test setext-3 "Setext anchor generated" -body {
    set md "Hello World\n===========\n"
    set ast [mdstack::parser::parse $md]
    set h [lindex [dict get $ast blocks] 0]
    dict get $h anchor
} -result {hello-world}

test setext-4 "Hr still works when prev line empty" -body {
    set md "\n---\n"
    set ast [mdstack::parser::parse $md]
    set b [lindex [dict get $ast blocks] 0]
    dict get $b type
} -result {hr}

test setext-5 "Setext H2 beats Hr when text precedes" -body {
    set md "Title\n---\n\nBody."
    set ast [mdstack::parser::parse $md]
    set b [lindex [dict get $ast blocks] 0]
    list [dict get $b type] [dict get $b level]
} -result {heading 2}

# --- Math (v0.2.10) ---

test math-inline-1 "parse inline math" -body {
    set md {The formula $E = mc^2$ is famous.}
    set ast [mdstack::parser::parse $md]
    set p [lindex [dict get $ast blocks] 0]
    set inlines [dict get $p content]
    # Find math inline
    set found ""
    foreach i $inlines {
        if {[dict get $i type] eq "math"} {
            set found [dict get $i text]
            break
        }
    }
    set found
} -result {E = mc^2}

test math-inline-2 "inline math display flag is 0" -body {
    set md {Use $x$ here.}
    set ast [mdstack::parser::parse $md]
    set p [lindex [dict get $ast blocks] 0]
    set inlines [dict get $p content]
    set found ""
    foreach i $inlines {
        if {[dict get $i type] eq "math"} {
            set found [dict get $i display]
            break
        }
    }
    set found
} -result {0}

test math-inline-3 "no false match: dollar prices" -body {
    set md {Costs $5 and $10 total.}
    set ast [mdstack::parser::parse $md]
    set p [lindex [dict get $ast blocks] 0]
    set inlines [dict get $p content]
    set hasMath 0
    foreach i $inlines {
        if {[dict get $i type] eq "math"} { set hasMath 1 }
    }
    set hasMath
} -result {0}

test math-inline-4 "no false match: explanatory paragraph with backtick-dollar" -body {
    # Genau der Bug aus extended-markdown.md: $10 schaltet ... `$`
    # wurde faelschlich als ein riesiger Math-Block geparst.
    set md {Bei Preisen wie $5 oder $10 schaltet der Parser nicht in den Math-Modus -- das ist intentional. Die Erkennung verlangt, dass nach dem oeffnenden `$` kein Leerzeichen kommt.}
    set ast [mdstack::parser::parse $md]
    set p [lindex [dict get $ast blocks] 0]
    set hasMath 0
    foreach i [dict get $p content] {
        if {[dict get $i type] eq "math"} { set hasMath 1 }
    }
    set hasMath
} -result {0}

test math-inline-5 "no false match: dollar followed by space" -body {
    set md {Cost: $ 5 here.}
    set ast [mdstack::parser::parse $md]
    set p [lindex [dict get $ast blocks] 0]
    set hasMath 0
    foreach i [dict get $p content] {
        if {[dict get $i type] eq "math"} { set hasMath 1 }
    }
    set hasMath
} -result {0}

test math-inline-6 "math with digits inside still works" -body {
    set md {Solve $x = 5$ here.}
    set ast [mdstack::parser::parse $md]
    set p [lindex [dict get $ast blocks] 0]
    set hasMath 0
    set txt ""
    foreach i [dict get $p content] {
        if {[dict get $i type] eq "math"} {
            set hasMath 1
            set txt [dict get $i text]
        }
    }
    list $hasMath $txt
} -result {1 {x = 5}}

test math-block-1 "display math block" -body {
    set md "Before.\n\n\$\$\nx = y\n\$\$\n\nAfter."
    set ast [mdstack::parser::parse $md]
    # Find math_block
    set found ""
    foreach b [dict get $ast blocks] {
        if {[dict get $b type] eq "math_block"} {
            set found [dict get $b content]
            break
        }
    }
    string trim $found
} -result {x = y}

test math-block-2 "display math block display flag" -body {
    set md "\$\$\na + b\n\$\$"
    set ast [mdstack::parser::parse $md]
    set b [lindex [dict get $ast blocks] 0]
    list [dict get $b type] [dict get $b display]
} -result {math_block 1}

test math-block-3 "single line dollar-dollar" -body {
    set md "\$\$E=mc^2\$\$"
    set ast [mdstack::parser::parse $md]
    set b [lindex [dict get $ast blocks] 0]
    list [dict get $b type] [dict get $b content]
} -result {math_block E=mc^2}

# --- Mermaid (just verifies language is preserved) ---

test mermaid-1 "fenced code with mermaid language" -body {
    set md "\`\`\`mermaid\ngraph TD\n  A --> B\n\`\`\`"
    set ast [mdstack::parser::parse $md]
    set b [lindex [dict get $ast blocks] 0]
    list [dict get $b type] [dict get $b language]
} -result {code_block mermaid}

cleanupTests
