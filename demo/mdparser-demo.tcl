#!/usr/bin/env tclsh
# mdparser-demo.tcl -- Complete parser feature demo (CLI)
#
# Demonstrates ALL parser features with AST output.
# Usage: tclsh mdparser-demo.tcl

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require mdparser 0.2

# Helper: Inline-Liste zu Plain-Text
proc inlinesToText {inlines} {
    set txt ""
    foreach i $inlines {
        switch [dict get $i type] {
            text         { append txt [dict get $i value] }
            inline_code  { append txt "`[dict get $i value]`" }
            strong - emphasis - strike {
                append txt [inlinesToText [dict get $i content]]
            }
            link {
                append txt [inlinesToText [dict get $i label]]
            }
            image {
                append txt "![dict get $i alt]"
            }
            linebreak {
                append txt " | "
            }
            span {
                append txt [inlinesToText [dict get $i content]]
            }
            footnote_ref {
                append txt "\[^[dict get $i id]\]"
            }
        }
    }
    return $txt
}

proc showBlocks {blocks {indent ""}} {
    foreach block $blocks {
        set type [dict get $block type]
        switch $type {
            heading {
                set text [inlinesToText [dict get $block content]]
                puts "${indent}H[dict get $block level]: $text (anchor=[dict get $block anchor])"
            }
            paragraph {
                set text [inlinesToText [dict get $block content]]
                if {[string length $text] > 60} {
                    set text "[string range $text 0 57]..."
                }
                puts "${indent}PARA: $text"
            }
            code_block {
                set lang [dict get $block language]
                set lines [llength [split [dict get $block text] "\n"]]
                puts "${indent}CODE: lang=$lang, $lines lines"
            }
            table {
                set cols [llength [dict get $block header]]
                set rows [llength [dict get $block rows]]
                puts "${indent}TABLE: ${cols}x${rows}, align=[dict get $block alignments]"
                # Header
                set hdr {}
                if {[dict exists $block headerInlines]} {
                    foreach cell [dict get $block headerInlines] {
                        lappend hdr [inlinesToText $cell]
                    }
                } else {
                    set hdr [dict get $block header]
                }
                puts "${indent}  Header: [join $hdr { | }]"
            }
            list {
                set style [dict get $block style]
                set items [dict get $block items]
                set hasTask 0
                foreach item $items {
                    if {[dict exists $item checked]} { set hasTask 1 }
                }
                set kind [expr {$hasTask ? "TASKLIST" : "[string toupper $style]LIST"}]
                puts "${indent}${kind}: [llength $items] items"
                foreach item $items {
                    set checked ""
                    if {[dict exists $item checked]} {
                        set checked [expr {[dict get $item checked] ? "\[x\] " : "\[ \] "}]
                    }
                    set text ""
                    if {[dict exists $item blocks]} {
                        set pb [lindex [dict get $item blocks] 0]
                        if {[dict exists $pb content]} {
                            set text [inlinesToText [dict get $pb content]]
                        }
                    } elseif {[dict exists $item content]} {
                        set text [inlinesToText [dict get $item content]]
                    }
                    puts "${indent}  - ${checked}$text"
                }
            }
            blockquote {
                puts "${indent}QUOTE:"
                showBlocks [dict get $block blocks] "${indent}  "
            }
            hr {
                puts "${indent}HR"
            }
            image {
                puts "${indent}IMAGE: alt=[dict get $block alt] url=[dict get $block url]"
            }
            deflist {
                set items [dict get $block items]
                puts "${indent}DEFLIST: [llength $items] entries"
                foreach item $items {
                    set term [dict get $item termText]
                    puts "${indent}  $term"
                    foreach def [dict get $item definitions] {
                        puts "${indent}    : [inlinesToText $def]"
                    }
                }
            }
            div {
                set cls [dict get $block class]
                puts "${indent}DIV: class=$cls"
            }
            footnote_section {
                set fns [dict get $block footnotes]
                puts "${indent}FOOTNOTES: [llength $fns] definitions"
                foreach fn $fns {
                    puts "${indent}  \[^[dict get $fn id]\]: [inlinesToText [dict get $fn content]]"
                }
            }
            default {
                puts "${indent}[string toupper $type]"
            }
        }
    }
}

# ============================================================
puts "=== Demo 1: YAML Frontmatter ==="
set md1 {---
title: Parser Demo
version: 2.0
section: n
---

# Document with metadata

Content.
}
set ast1 [mdparser::parse $md1]
puts "Meta: [dict get $ast1 meta]"
showBlocks [dict get $ast1 blocks]
puts ""

# ============================================================
puts "=== Demo 2: Alle Heading-Levels + Closing Hashes ==="
set md2 {# H1
## H2
### H3
#### H4
##### H5
###### H6
## Closing Hashes ##
}
set ast2 [mdparser::parse $md2]
showBlocks [dict get $ast2 blocks]
puts ""

# ============================================================
puts "=== Demo 3: Inline Formatting ==="
set md3 {**Bold**, *italic*, ***both***, ~~strike~~, `code`.
Double backtick: ``code with `backtick` inside``.
Backslash: \*escaped\*.
Link: [Tcl](https://www.tcl.tk "Title").
Image: ![icon](icon.png "Alt").
Hard Break: line one  
Line two.
Bare URL: https://www.tcl.tk
Autolink: <user@example.com>
}
set ast3 [mdparser::parse $md3]
set para [lindex [dict get $ast3 blocks] 0]
puts "Inline types in first paragraph:"
foreach i [dict get $para content] {
    set t [dict get $i type]
    switch $t {
        text        { puts "  TEXT: '[dict get $i value]'" }
        strong      { puts "  STRONG: [inlinesToText [dict get $i content]]" }
        emphasis    { puts "  EM: [inlinesToText [dict get $i content]]" }
        strike      { puts "  STRIKE: [inlinesToText [dict get $i content]]" }
        inline_code { puts "  CODE: '[dict get $i value]'" }
        link        { puts "  LINK: url=[dict get $i url] title=[expr {[dict exists $i title] ? [dict get $i title] : {}}]" }
        image       { puts "  IMAGE: alt=[dict get $i alt] title=[expr {[dict exists $i title] ? [dict get $i title] : {}}]" }
        linebreak   { puts "  LINEBREAK" }
    }
}
puts ""

# ============================================================
puts "=== Demo 4: Reference Links + Images ==="
set md4 {[Tcl Docs][tcldoc] and [Tk][tkref].
Shortcut: [encoding].
Image: ![Screenshot][screen1]

[tcldoc]: https://www.tcl.tk/man/tcl/ "Tcl Manpages"
[tkref]: https://www.tcl.tk/man/tcl/TkCmd/
[encoding]: encoding.md
[screen1]: images/screenshot.png
}
set ast4 [mdparser::parse $md4]
puts "Reflinks: [dict get $ast4 reflinks]"
showBlocks [dict get $ast4 blocks]
puts ""

# ============================================================
puts "=== Demo 5: Code-Bloecke (Backtick, Tilde, Indent) ==="
set md5 "```tcl\nputs \"Backtick-Fence\"\n```\n\n~~~python\nprint(\"Tilde-Fence\")\n~~~\n\n    puts \"Indented Code\""
set ast5 [mdparser::parse $md5]
showBlocks [dict get $ast5 blocks]
puts ""

# ============================================================
puts "=== Demo 6: Tables ==="
set md6 {| Left | Center | Right |
|:-----|:------:|------:|
| AAA | BBB | 100 |
| CCC | DDD | 200 |
}
set ast6 [mdparser::parse $md6]
showBlocks [dict get $ast6 blocks]
puts ""

# ============================================================
puts "=== Demo 7: Lists (ul, ol, task, nested) ==="
set md7a {- Item 1
  - Sub-item A
  - Sub-item B
- Item 2
}
set md7b {1. One
2. Two
3. Three
}
set md7c {- [ ] Open
- [x] Done
}

foreach {label md} [list "Unordered" $md7a "Ordered" $md7b "Task" $md7c] {
    set ast [mdparser::parse $md]
    set lst [lindex [dict get $ast blocks] 0]
    set style [dict get $lst style]
    set items [dict get $lst items]
    puts "  $label ($style, [llength $items] items):"
    foreach item $items {
        set checked ""
        if {[dict exists $item checked]} {
            set checked [expr {[dict get $item checked] ? " \[x\]" : " \[ \]"}]
        }
        set text ""
        if {[dict exists $item blocks]} {
            set pb [lindex [dict get $item blocks] 0]
            if {[dict exists $pb content]} {
                set text [inlinesToText [dict get $pb content]]
            }
        } elseif {[dict exists $item content]} {
            set text [inlinesToText [dict get $item content]]
        }
        puts "    ${checked} $text"
    }
}
puts ""

# ============================================================
puts "=== Demo 8: Blockquotes (nested) ==="
set md8 {> Outer quote.
> > Inner quote.
> > Another line.
>
> Back outside.
}
set ast8 [mdparser::parse $md8]
showBlocks [dict get $ast8 blocks]
puts ""

# ============================================================
puts "=== Demo 9: HR Variants ==="
set md9 "---\n\n***\n\n___"
set ast9 [mdparser::parse $md9]
showBlocks [dict get $ast9 blocks]
puts ""

# ============================================================
puts "=== Demo 10: Definition Lists ==="
set md10 {API
: Application Programming Interface

CLI
: Command Line Interface
: Command-line interface
}
set ast10 [mdparser::parse $md10]
showBlocks [dict get $ast10 blocks]
puts ""

# ============================================================
puts "=== Demo 11: Footnotes ==="
set md11 {Text with footnote[^1] und [^note].

[^1]: First footnote.
[^note]: Second footnote with
  continuation line.
}
set ast11 [mdparser::parse $md11]
showBlocks [dict get $ast11 blocks]
puts ""

# ============================================================
puts "=== Demo 12: Fenced Divs ==="
set md12 {::: {.synopsis}
Command syntax here.
:::

::: warning
Caution!
:::
}
set ast12 [mdparser::parse $md12]
showBlocks [dict get $ast12 blocks]
puts ""

# ============================================================
puts "=== Demo 13: Bracketed Spans (TIP-700) ==="
set md13 {[array]{.cmd} [get]{.sub} [arrayName]{.arg} [pattern]{.optarg}}
set ast13 [mdparser::parse $md13]
set para [lindex [dict get $ast13 blocks] 0]
foreach i [dict get $para content] {
    if {[dict get $i type] eq "span"} {
        set text [inlinesToText [dict get $i content]]
        puts "  SPAN: text=$text class=[dict get $i class]"
    }
}
puts ""

# ============================================================
puts "=== Demo 14: Standalone Images ==="
set md14 {Text before.

![App Screenshot](images/app.png)

Text after.
}
set ast14 [mdparser::parse $md14]
showBlocks [dict get $ast14 blocks]
puts ""

# ============================================================
puts "=== Demo 15: Complete Document ==="
set md15 {---
title: Project Report
version: 1.0
---

# Project Report

> **Zusammenfassung:** Das Projekt ist auf gutem Weg.

## Status Table

| Modul | Status | Responsible |
|-------|--------|----------------|
| Backend | done | Max |
| Frontend | in progress | Anna |

## Screenshot

![App Screenshot](images/app.png)

## TODO

- [x] Design complete
- [ ] Write tests[^todo]
- [ ] Deployment

API
: Application Programming Interface

[^todo]: First tests are already running.

---

*End of report.*
}
set ast15 [mdparser::parse $md15]
puts "Document with [llength [dict get $ast15 blocks]] blocks:"
puts "Meta: [dict get $ast15 meta]"
showBlocks [dict get $ast15 blocks]
puts ""

# ============================================================
puts "=== Summary ==="
puts "Tested block types:  heading, paragraph, code_block, table,"
puts "  list, blockquote, hr, image, deflist, div, footnote_section"
puts "Tested inline types: text, strong, emphasis, strike,"
puts "  inline_code, link, image, linebreak, span, footnote_ref"
puts "Extras: YAML frontmatter, reference links/images,"
puts "  autolinks, bare URLs, tilde fences, indented code,"
puts "  closing hashes, backslash escapes, hard breaks"
