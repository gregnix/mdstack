# Introduction

DocIR is a hub architecture for document conversion. A [source]{.index}
reads an input format into a common intermediate representation, the
[DocIR]{.index} (Document Intermediate Representation). Arbitrary
[sink]{.index}s produce the output formats from it. Sources and sinks do
not know each other; they communicate only through the IR.

## The hub-and-spoke principle

A new source is immediately served by all sinks, and a new sink
immediately benefits from all sources. This keeps the number of converters
linear instead of quadratic: no source needs to know any sink — only the
IR.

## The usual path

For Markdown the path runs through the [mdstack]{.index} parser to the
AST, from there through `docir::md::fromAst` into the IR, and finally
through a sink such as `docir::pdf` or `docir::html` into the output
format.

```tcl
package require mdstack::parser
package require docir::mdSource
package require docir::pdf

set ast [mdstack::parser::parse $markdown]
set ir  [docir::md::fromAst $ast]
docir::pdf::render $ir out.pdf {}
```

## About this handbook

This handbook is itself an example of the book convention: Markdown
chapters without fixed numbers, index terms written as `[term]{.index}`,
an order defined in `book.tcl`, and a build to PDF and HTML via
`book-build.tcl` (from the **bookkit** toolkit).
