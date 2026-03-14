#!/usr/bin/env tclsh
# demo-tip700.tcl -- Demonstriert alle TIP-700-Features
#
# New features:
#   1. YAML Frontmatter (Metadaten)
#   2. Bracketed Spans [text]{.class} (semantische Syntax)
#   3. Shortcut Reference Links [text]
#   4. Fenced Divs ::: {.class} ... :::
#   5. AST-Validator (mdvalidator)

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require mdparser 0.2
package require mdvalidator 0.1

# ====================================================================
# Helper
# ====================================================================

proc inlinesToText {inlines} {
    set txt ""
    foreach i $inlines {
        switch [dict get $i type] {
            text        { append txt [dict get $i value] }
            inline_code { append txt "`[dict get $i value]`" }
            strong      { append txt "**[inlinesToText [dict get $i content]]**" }
            emphasis    { append txt "*[inlinesToText [dict get $i content]]*" }
            strike      { append txt "~~[inlinesToText [dict get $i content]]~~" }
            span {
                set cls [dict get $i class]
                append txt "\[[inlinesToText [dict get $i content]]\]{.$cls}"
            }
            link {
                append txt "\[[inlinesToText [dict get $i label]]\]"
            }
            linebreak { append txt "\n" }
        }
    }
    return $txt
}

proc printBlock {block {indent ""}} {
    set type [dict get $block type]
    switch $type {
        heading {
            set lvl [dict get $block level]
            set txt [inlinesToText [dict get $block content]]
            puts "${indent}H$lvl: $txt"
        }
        paragraph {
            set txt [inlinesToText [dict get $block content]]
            if {[string length $txt] > 70} {
                set txt "[string range $txt 0 66]..."
            }
            puts "${indent}P:  $txt"
        }
        code_block {
            set lang [dict get $block language]
            set lines [llength [split [dict get $block text] "\n"]]
            puts "${indent}CODE($lang): $lines lines"
        }
        list {
            set s [dict get $block style]
            set n [llength [dict get $block items]]
            puts "${indent}LIST($s): $n Items"
            foreach item [dict get $block items] {
                set firstBlock [lindex [dict get $item blocks] 0]
                if {[dict get $firstBlock type] eq "paragraph"} {
                    set txt [inlinesToText [dict get $firstBlock content]]
                    puts "${indent}  - $txt"
                }
            }
        }
        div {
            set cls [dict get $block class]
            set n [llength [dict get $block blocks]]
            puts "${indent}DIV(.$cls): $n innere Bloecke"
            foreach inner [dict get $block blocks] {
                printBlock $inner "${indent}  "
            }
        }
        hr {
            puts "${indent}---"
        }
        table {
            set cols [llength [dict get $block header]]
            set rows [llength [dict get $block rows]]
            puts "${indent}TABLE: $cols columns, $rows lines"
        }
        deflist {
            set n [llength [dict get $block items]]
            puts "${indent}DEFLIST: $n Terme"
        }
        blockquote {
            puts "${indent}QUOTE:"
            foreach inner [dict get $block blocks] {
                printBlock $inner "${indent}  "
            }
        }
        default {
            puts "${indent}$type"
        }
    }
}

proc hr {} { puts [string repeat - 60] }

# ====================================================================
# Demo 1: YAML Frontmatter
# ====================================================================

hr
puts "=== 1. YAML Frontmatter ==="
hr
puts ""

set md1 {---
title: array
section: n
manual-section: Tcl Built-In Commands
version: 9.0
---

# array

Manipulate array variables.
}

set ast1 [mdparser::parse $md1]

puts "Metadaten aus YAML:"
dict for {k v} [dict get $ast1 meta] {
    puts "  $k = $v"
}
puts ""
puts "Bloecke nach Frontmatter:"
foreach b [dict get $ast1 blocks] {
    printBlock $b "  "
}
puts ""

# ====================================================================
# Demo 2: Bracketed Spans (Kern-Feature TIP 700)
# ====================================================================

hr
puts "=== 2. Bracketed Spans ==="
hr
puts ""

set md2 {## Synopsis

[array]{.cmd} [option]{.arg} [arrayName]{.arg} [arg]{.optdot}

[array]{.cmd} [get]{.sub} [arrayName]{.arg} [pattern]{.optarg}

[return]{.cmd} [[-code]{.lit} [code]{.arg}]{.optarg} [result]{.optarg}

[puts]{.cmd} [-nonewline]{.optlit} [channel]{.optarg} [string]{.arg}

[pathName]{.ins} [addtag]{.sub} [tag]{.arg} [searchSpec]{.arg} [arg]{.optdot}
}

set ast2 [mdparser::parse $md2]

puts "Tcl-Kommandosyntax (semantisch geparst):"
puts ""
foreach b [dict get $ast2 blocks] {
    if {[dict get $b type] eq "paragraph"} {
        puts "  [inlinesToText [dict get $b content]]"
        puts ""
        # Zeige Span-Details
        set spans {}
        foreach i [dict get $b content] {
            if {[dict get $i type] eq "span"} {
                set cls [dict get $i class]
                set txt [inlinesToText [dict get $i content]]
                lappend spans "${txt}(.${cls})"
            }
        }
        if {[llength $spans] > 0} {
            puts "    Spans: [join $spans {, }]"
            puts ""
        }
    } else {
        printBlock $b "  "
    }
}

# ====================================================================
# Demo 3: C API Syntax
# ====================================================================

hr
puts "=== 3. C API Syntax ==="
hr
puts ""

set md3 {[Tcl_AllowExceptions]{.ccmd} [interp]{.cargs}

[Tcl_SetByteArrayObj]{.ccmd} [objPtr, bytes, numBytes]{.cargs}

[unsigned char *]{.ret} [Tcl_GetBytesFromObj]{.ccmd} [interp, objPtr, numBytesPtr]{.cargs}
}

set ast3 [mdparser::parse $md3]

puts "C API Funktionen:"
puts ""
foreach b [dict get $ast3 blocks] {
    if {[dict get $b type] eq "paragraph"} {
        set parts {}
        foreach i [dict get $b content] {
            if {[dict get $i type] eq "span"} {
                set cls [dict get $i class]
                set txt [inlinesToText [dict get $i content]]
                switch $cls {
                    ret   { lappend parts $txt }
                    ccmd  { lappend parts "${txt}(" }
                    cargs { lappend parts "${txt})" }
                }
            }
        }
        puts "  [join $parts {}]"
    }
}
puts ""

# ====================================================================
# Demo 4: Shortcut Reference Links
# ====================================================================

hr
puts "=== 4. Shortcut Reference Links ==="
hr
puts ""

set md4 {See the [encoding] command for details. The [binary scan][binary]
subcommand uses similar syntax. Also check [lsort] and [lsearch].

[encoding]: encoding.md
[binary]: binary.md "Binary Format and Scan"
[lsort]: lsort.md
[lsearch]: lsearch.md "List Search Command"
}

set ast4 [mdparser::parse $md4]

puts "Referenz-Links:"
dict for {k v} [dict get $ast4 reflinks] {
    puts "  \[$k\] -> [dict get $v url]"
    if {[dict get $v title] ne ""} {
        puts "    Title: [dict get $v title]"
    }
}
puts ""

puts "Paragraph mit aufgeloesten Links:"
set para [lindex [dict get $ast4 blocks] 0]
foreach i [dict get $para content] {
    if {[dict get $i type] eq "link"} {
        set label [inlinesToText [dict get $i label]]
        set url [dict get $i url]
        puts "  Link: $label -> $url"
    }
}
puts ""

# ====================================================================
# Demo 5: Fenced Divs
# ====================================================================

hr
puts "=== 5. Fenced Divs ==="
hr
puts ""

set md5 {::: {.synopsis}
[array]{.cmd} [option]{.arg} [arrayName]{.arg}
[array]{.cmd} [get]{.sub} [arrayName]{.arg} [pattern]{.optarg}
:::

## Description

The [array] command provides several operations.

::: {.example}
### Beispiel

```tcl
array set colors {red #ff0000 green #00ff00 blue #0000ff}
array get colors
```
:::

[array]: array.md
}

set ast5 [mdparser::parse $md5]

puts "Dokument-Struktur:"
foreach b [dict get $ast5 blocks] {
    printBlock $b "  "
}
puts ""

# ====================================================================
# Demo 6: Verschachtelte Spans + Divs
# ====================================================================

hr
puts "=== 6. Verschachtelung ==="
hr
puts ""

set md6 {::: {.synopsis}
[return]{.cmd} [[-code]{.lit} [code]{.arg}]{.optarg} [[-level]{.lit} [level]{.arg}]{.optarg} [result]{.optarg}
:::
}

set ast6 [mdparser::parse $md6]

puts "Verschachtelte Spans:"
set div [lindex [dict get $ast6 blocks] 0]
set para [lindex [dict get $div blocks] 0]

proc showSpanTree {inlines {indent ""}} {
    foreach i $inlines {
        set type [dict get $i type]
        if {$type eq "span"} {
            set cls [dict get $i class]
            set inner [dict get $i content]
            # Check if inner has sub-spans
            set hasSubSpans 0
            foreach sub $inner {
                if {[dict get $sub type] eq "span"} { set hasSubSpans 1 }
            }
            if {$hasSubSpans} {
                puts "${indent}SPAN(.$cls):"
                showSpanTree $inner "${indent}  "
            } else {
                set txt [inlinesToText $inner]
                puts "${indent}SPAN(.$cls): \"$txt\""
            }
        } elseif {$type eq "text"} {
            set v [string trim [dict get $i value]]
            if {$v ne ""} {
                puts "${indent}TEXT: \"$v\""
            }
        }
    }
}

showSpanTree [dict get $para content] "  "
puts ""

# ====================================================================
# Demo 7: Komplett -- TIP-700-Manpage
# ====================================================================

hr
puts "=== 7. Komplette TIP-700-Manpage ==="
hr
puts ""

set md7 {---
title: puts
section: n
manual-section: Tcl Built-In Commands
see-also: gets read
---

# puts

## Synopsis

::: {.synopsis}
[puts]{.cmd} [-nonewline]{.optlit} [channelId]{.optarg} [string]{.arg}
:::

## Description

Writes *string* to the specified [channelId]. See [gets] and [read]
for complementary operations.

## Examples

::: {.example}
```tcl
puts "Hello, World!"
puts -nonewline stderr "Error: "
puts stderr "something went wrong"
```
:::

## See Also

[gets], [read], [open], [close]

[gets]: gets.md
[read]: read.md
[open]: open.md
[close]: close.md
[channelId]: Tcl_OpenFileChannel.md
}

set ast7 [mdparser::parse $md7]

puts "Meta:"
dict for {k v} [dict get $ast7 meta] {
    puts "  $k: $v"
}
puts ""

puts "Struktur:"
foreach b [dict get $ast7 blocks] {
    printBlock $b "  "
}
puts ""

puts "Reflinks:"
dict for {k v} [dict get $ast7 reflinks] {
    puts "  $k -> [dict get $v url]"
}
puts ""

# ====================================================================
# Demo 8: AST-Validator
# ====================================================================

hr
puts "=== 8. AST-Validator ==="
hr
puts ""

puts "Validierung der TIP-700-Manpage:"
puts "  [mdvalidator::report $ast7]"
puts "  [mdvalidator::report $ast7 -strict]"
puts ""

# Kaputte ASTs erkennen
puts "Kaputte ASTs:"
puts ""

set bad1 [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type code lang "tcl" text "puts hi"]]]
puts "  Alt: type=code, lang=tcl"
foreach e [mdvalidator::validate $bad1 -strict] {
    puts "    -> $e"
}
puts ""

set bad2 [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type paragraph inlines [list [dict create type text value "x"]]]]]
puts "  Alt: paragraph.inlines statt paragraph.content"
foreach e [mdvalidator::validate $bad2] {
    puts "    -> $e"
}
puts ""

set bad3 [dict create type document version 1 meta {} reflinks {} blocks [list \
    [dict create type list ordered 0 items {}]]]
puts "  Alt: list.ordered statt list.style"
foreach e [mdvalidator::validate $bad3] {
    puts "    -> $e"
}
puts ""

puts "Alle 7 Demo-ASTs validieren:"
set all_valid 1
foreach ast [list $ast1 $ast2 $ast3 $ast4 $ast5 $ast6 $ast7] {
    set errs [mdvalidator::validate $ast]
    if {[llength $errs] > 0} {
        set all_valid 0
        puts "  ERROR: $errs"
    }
}
if {$all_valid} {
    puts "  Alle 7 ASTs valid (Spec v0.3)"
}
puts ""

hr
puts "Demo abgeschlossen."
