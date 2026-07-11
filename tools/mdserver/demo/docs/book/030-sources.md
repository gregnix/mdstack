# Sources

A [source]{.index} translates a source-format-specific AST into the IR.
The guiding principle is: the AST is close to the source, the IR is close
to the sinks. A source's mapping function may enrich, unify, and drop
whatever the sinks do not need.

## Markdown

`docir::mdSource` provides `docir::md::fromAst`. The input is the AST of
the [mdstack]{.index} parser, the output is the IR.

```tcl
set ast [mdstack::parser::parse $markdown]
set ir  [docir::md::fromAst $ast]
```

Markdown headings become `heading` with `meta.level` taken from the number
of `#`. Each heading receives an anchor via `meta.id` (a slug derived from
the title) that is later used for cross-references and tables.

## nroff

`docir::roffSource` provides `docir::roff::fromAst` and translates the AST
of the nroff parser. Here unification is especially visible: nroff `.SH`
becomes `heading level=1`, `.SS` becomes `heading level=2`, and the nroff
`.TH` becomes the `doc_header`.

## The term "heading"

A well-known stumbling block: in a source-near AST, `heading` can mean
something different from the IR. In the nroff AST, `heading` is the manpage
header (`.TH`); in the IR, `heading` is the generic heading. Sources
resolve this during mapping; in the IR the sink-near meaning holds
throughout.
