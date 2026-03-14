---
title: PDF Export Feature Demo
version: 4.2
---

# PDF Export Feature Demo

All Markdown features supported by the PDF export.

## Text Formatting

**Bold**, *italic*, ***bold and italic***, ~~strikethrough~~.

`Inline code` with monospace font.

## Tables

| Column 1 | Column 2 | Column 3 |
|----------|:--------:|---------:|
| Left     | Center   | Right    |
| Text     | **Bold** | *Italic* |
| Long     | Medium   | Short    |

## Blockquotes

> This is an **important** quote with *italic* text.
>
> Multi-line quote with `Code`.

### Nested Blockquotes

> Outer blockquote.
>
> > Inner nested blockquote.
> >
> > > Deeply nested level three.

## Code Blocks

### Backtick Fence

```tcl
proc test {} {
    puts "Hello World"
}
```

### Tilde Fence

~~~python
def hello():
    print("Hello!")
~~~

### Indented Code Block

    set x 42
    puts "Value: $x"

## Lists

- First item
- Second item
  - Sub-item A
  - Sub-item B
- Third item

1. Numbered
2. List
3. Example

### Task List

- [ ] Open
- [x] Done
- [ ] Still open

## Links

Inline link: [Tcl Developer Xchange](https://www.tcl.tk).

Autolink URL: <https://www.tcl.tk>

Reference link: [Tcl Wiki][tclwiki]

[tclwiki]: https://wiki.tcl-lang.org

Multiple links in one sentence: visit [GitHub](https://github.com/gregnix/pdf4tcl)
or [SourceForge](https://sourceforge.net/projects/pdf4tcl/) for the source code.

**Note:** All links above are clickable in the PDF viewer (requires mdpdf 0.2
with pdf4tcl 0.9.4.11 and the hyperlinkAdd support).

## PDF Export Options (mdpdf 0.2 / pdf4tcl 0.9.4.11)

New options available via `mdpdf::export` and `mdpdf::exportFile`:

PDF/A archiving mode:

```tcl
mdpdf::exportFile input.md output.pdf -pdfa 1b
```

Password protection (AES-128):

```tcl
mdpdf::exportFile input.md output.pdf -userpassword "secret"
mdpdf::exportFile input.md output.pdf -ownerpassword "admin"
```

Compression control:

```tcl
mdpdf::exportFile input.md output.pdf -compress 0
```

## Images

![Example Image](images/demo.png)

If the image does not exist, the alt text is shown.

## Definition Lists

API
: Application Programming Interface

CLI
: Command Line Interface

## Spans (TIP 700)

Command [proc]{.cmd}, argument [filename]{.arg}, literal value [42]{.lit}.

## Horizontal Rules

---

***

## Hard Line Breaks

Line one with two trailing spaces  
Line two starts here.

Line with backslash break\
Next line continues.

## Backslash Escapes

\*Not italic\*, \*\*not bold\*\*, \`not code\`.

## Footnotes

Text with footnote[^1] and named reference[^note].

[^1]: First footnote.
[^note]: Second footnote with continuation line.

## TrueType Fonts

With TrueType fonts, special characters can be displayed correctly:
Apples, accented characters. Special chars: right arrow, left arrow.

---

*End of PDF demo.*
