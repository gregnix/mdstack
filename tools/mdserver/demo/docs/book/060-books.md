# Building Books

A book is a directory of Markdown chapters that `book-build.tcl` (from the
**bookkit** toolkit) typesets in a single run to PDF and HTML.

## Layout

One directory, one file per chapter. Headings carry **no** numbers in the
source; chapter and section numbers are produced during the build.

```
mybook/
    book.tcl
    010-introduction.md
    020-concepts.md
```

## Order

There are two ways; the manifest takes precedence. If a [book.tcl]{.index}
exists, it defines the order via a `chapters` list (optionally also
`title` and `author`); the filename prefix is then ignored. Without the
manifest, the numeric [prefix]{.index} in the filename determines the
order. A generator run writes a manifest from the prefixes, which can then
be reordered freely:

```
tclsh bookkit/tools/book-build.tcl manifest mybook/
```

## Numbering and stable references

The `-number` option assigns hierarchical numbers (`1`, `1.1`, `1.1.1`)
from nesting and order. Because the [numbering]{.index} happens on the IR,
it appears consistently in the text, the table of contents, the bookmarks,
and in both output formats.

Anchors are built from the title, not from the number. Reordering
therefore changes the numbers but not the anchors — cross-references to
`#title-anchor` remain valid.

## Building

```
tclsh bookkit/tools/book-build.tcl mybook/ -number
tclsh bookkit/tools/book-build.tcl mybook/ -pdf out.pdf -html out.html -number
```

Without `-pdf`/`-html`, both formats are produced next to the book
directory. The switches `-no-toc` and `-no-index` omit the tables,
`-depth N` controls the depth of numbering and table of contents.
