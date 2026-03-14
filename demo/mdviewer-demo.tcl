#!/usr/bin/env wish
# mdviewer-demo.tcl -- Complete viewer feature demo
#
# Shows ALL Markdown features supported by the parser/viewer
# in a scrollable window. Replaces the earlier individual demos
# (blockquote, deflist, image, nested-lists, table, anchor-fontsize).
#
# Usage: wish mdviewer-demo.tcl

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require Tk 8.6-
package require mdparser  0.2
package require mdmodel   0.1
package require mdviewer   0.3

proc onLink {url} {
    tk_messageBox -title "Link" -message "URL: $url"
}

# --- Markdown with ALL Features ---
set md {# mdviewer Feature-Demo

This demo shows all Markdown features supported by mdviewer.

## Headings

All six levels are supported.
Closing hashes are removed (e.g. `## Title ##`).

### Level 3

#### Level 4

##### Level 5

###### Level 6

## Text Formatting

**Bold** is written with double asterisks.
*Italic* with single asterisks.
***Bold and italic*** with triple.
~~Strikethrough~~ with tildes.
`Inline code` with backticks.
Double backticks: ``Code with `backtick` inside``.
Backslash escapes: \*not italic\*, \[not a link\].

### Hard Line Break

First line  
Second line (same paragraph, hard break).

## Links

Inline link: [Tcl/Tk Homepage](https://www.tcl.tk)
Link with title: [Wiki](https://wiki.tcl-lang.org "Tcl Wiki")
Anchor link: [To top](#mdviewer-feature-demo)
Reference link: [Tcl Docs][tcldoc]
Shortcut reference: [encoding]
Autolink: <https://www.tcl.tk>
Bare URL: https://www.tcl.tk

[tcldoc]: https://www.tcl.tk/man/tcl/ "Tcl Manpages"
[encoding]: https://www.tcl.tk/man/tcl/TclCmd/encoding.htm

## Images

Standalone image (own block):

![Demo Image](images/demo.png)

Inline image: Text with ![Icon](icons/tcl.png) in sentence.

Reference image: ![Screenshot][screen1]

[screen1]: images/screenshot.png "Main window"

## Listen

### Unordered Lists

- First item
- Second item
  - Sub-item A
  - Sub-item B
    - Deeply nested
- Third item

### Ordered Lists

1. Step one
2. Step two
3. Step three

### Task Lists

- [ ] Task open
- [x] Task done
- [ ] Another task

### List with Formatting

- **Bold** and `code` in one item
- *Italic* with [Link](https://example.com)
- ~~Strikethrough~~ and `inline code`

## Code Blocks

### Backtick Fence with Language

```tcl
proc greet {name} {
    puts "Hello $name!"
}
greet "World"
```

### Tilde Fence

~~~python
def hello(name):
    print(f"Hello {name}!")
~~~

### Indented Code (4 Spaces)

    set x [expr {1 + 2}]
    puts "Result: $x"

## Tables

### Simple Table

| Name | Type | Status |
|------|------|--------|
| Alpha | Lib | OK |
| Beta | App | Test |

### Table with Alignment

| Left | Center | Right |
|:-----|:------:|------:|
| AAA | BBB | 100 |
| CCC | DDD | 200 |
| EEE | FFF | 300 |

### Table with Formatting

| Feature | Syntax | Example |
|---------|--------|---------|
| **Bold** | `**text**` | **yes** |
| *Italic* | `*text*` | *yes* |
| `Code` | `` `text` `` | `yes` |
| [Link](https://example.com) | `[t](url)` | active |

## Blockquotes

> Simple quote.
> Spanning multiple lines.

> **Quote with formatting:**
> Text with *italic*, **bold** and `code`.

Nested quotes:

> Outer quote.
> > Inner quote.
> > Second line inside.
>
> Back outside.

## Horizontal Rules

Three different variants:

---

***

___

## Definition Lists

API
: Application Programming Interface

CLI
: Command Line Interface
: Command-line interface

`proc`
: Defines a **procedure** in Tcl.

## Footnotes

Text with footnote[^1] and named reference[^note].

[^1]: First footnote.
[^note]: Second footnote with
  continuation line (2 spaces indentation).

## Anchor Navigation

Heading anchors are set automatically.
Click on [Headings](#headings) to jump there.

---

*End of feature demo.*
}

# --- Build Window ---
wm title . "mdviewer Feature-Demo"
wm geometry . 700x800

set ast [mdparser::parse $md]
set doc [mdmodel::new $ast]
set rootDir [file dirname [info script]]

# Toolbar: Font Size
frame .tb -relief groove -bd 1
label .tb.l -text "Font:"
button .tb.minus -text "A-" -width 3 -command { changeFontSize -1 }
label .tb.size -textvariable ::fontSize -width 3
button .tb.plus -text "A+" -width 3 -command { changeFontSize 1 }
pack .tb.l .tb.minus .tb.size .tb.plus -side left -padx 2 -pady 2
pack .tb -side top -fill x

# Viewer
set v [mdviewer::create .v -onlink onLink -root $rootDir -tablemode frame]
pack $v -fill both -expand 1

mdviewer::renderModel $v $doc

# Font Size
set fontSize 11
proc changeFontSize {delta} {
    global v fontSize
    incr fontSize $delta
    if {$fontSize < 8} { set fontSize 8 }
    if {$fontSize > 24} { set fontSize 24 }
    mdviewer::setFontSize $v $fontSize
}
