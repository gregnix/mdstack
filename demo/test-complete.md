---
title: Complete Viewer Test
version: 4.2
section: test
---

# mdviewer Test File -- Complete Viewer Test

This file tests ALL Markdown features supported by the viewer.

---

## 1. Headings

# H1 Heading
## H2 Heading
### H3 Heading
#### H4 Heading
##### H5 Heading
###### H6 Heading

## Closing Hashes ##

---

## 2. Text Formatting

**Bold**, *italic*, ***bold and italic***, ~~strikethrough~~.

`Inline code` and double backticks: ``Code with `backtick` inside``.

Backslash escapes: \*not italic\*, \[not a link\].

### Hard Line Break

First line  
Second line (same paragraph).

---

## 3. Links

Inline link: [Tcl/Tk](https://www.tcl.tk)

Link with title: [Wiki](https://wiki.tcl-lang.org "Tcl Wiki")

Reference link: [Tcl Docs][tcldoc]

Shortcut reference: [encoding]

Autolink: <https://www.tcl.tk>

Bare URL: https://www.tcl.tk

Anchor link: [To top](#mdviewer-test-file----complete-viewer-test)

[tcldoc]: https://www.tcl.tk/man/tcl/ "Tcl Manpages"
[encoding]: https://www.tcl.tk/man/tcl/TclCmd/encoding.htm

---

## 4. Images

Standalone image:

![Demo Image](images/demo.png)

Inline image: Text with ![Icon](icons/tcl.png) in sentence.

Reference image: ![Screenshot][screen1]

[screen1]: images/screenshot.png "Main window"

---

## 5. Lists

### Unordered List

- Item one
- Item two
  - Sub-item A
  - Sub-item B
    - Deeply nested
- Item three

### Ordered List

1. First item
2. Second item
3. Third item

### Task List

- [ ] Still open
- [x] Done
- [ ] Also still open

### List with Formatting

- **Bold** and `code` in one item
- *Italic* with [Link](https://example.com)
- ~~Strikethrough~~ and `inline code`

---

## 6. Code Blocks

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

### Untyped Code Block

```
Without language tag.
```

### Indented Code

    set x [expr {1 + 2}]
    puts "Result: $x"

---

## 7. Tables

### Simple Table

| Name | Type | Status |
|------|------|--------|
| Alpha | Lib | OK |
| Beta | App | Test |
| Gamma | Tool | OK |

### Table with Alignment

| Left | Center | Right |
|:-----|:------:|------:|
| AAA | BBB | 100 |
| CCC | DDD | 200 |
| EEE | FFF | 300 |

### Table with Inline Formatting

| Feature | Syntax | Active |
|---------|--------|--------|
| **Bold** | `**text**` | **yes** |
| *Italic* | `*text*` | *yes* |
| `Code` | Backticks | `yes` |
| [Link](https://example.com) | `[t](url)` | yes |

---

## 8. Blockquotes

> Simple quote spanning multiple lines.
> Second line.

> **Quote with Formatting:**
> Text with *italic*, **bold** and `code`.

### Nested Blockquotes

> Outer quote.
> > Inner quote.
> > Second line inside.
>
> Back outside.

---

## 9. Horizontal Rules

---

***

___

---

## 10. Definition Lists

API
: Application Programming Interface

CLI
: Command Line Interface
: Command-line interface

`proc`
: Defines a **procedure** in Tcl.

`namespace`
: Organizes commands in *hierarchical* namespaces.

---

## 11. Footnotes

Text with numbered footnote[^1] and named reference[^note].

Another paragraph with third footnote[^three].

[^1]: First footnote.
[^note]: Second footnote with
  continuation line (2 spaces indentation).
[^three]: Third footnote.

---

## 12. Fenced Divs

::: {.synopsis}
[puts]{.cmd} [-nonewline]{.optlit} [channelId]{.optarg} [string]{.arg}
:::

::: warning
Caution: This is a warning.
:::

---

## 13. Bracketed Spans (TIP-700)

[array]{.cmd} [get]{.sub} [arrayName]{.arg} [pattern]{.optarg}

Available: `.cmd`, `.sub`, `.lit`, `.optlit`, `.arg`, `.optarg`.

---

## 14. Combination Test

> **Summary**
>
> - Blockquote with list
> - Formatting: **bold**, *italic*, `code`
>
> ```tcl
> puts "Code in quote"
> ```

---

## 15. Longer Text Passage (Scroll Test)

Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.

Duis aute irure dolor in reprehenderit in voluptate velit esse
cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat
cupidatat non proident, sunt in culpa qui officia deserunt mollit.

---

*End of viewer test.*
