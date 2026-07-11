# Your Own Source and Sink

The hub thrives on [source]{.index}s and [sink]{.index}s arising
independently of one another. Both are connected through the IR and need
not know each other.

## Writing a source

A source translates a source-format-specific AST into the IR. At its core
it is a function that produces the matching IR block for each AST node:

```tcl
namespace eval myformat {}

proc myformat::fromAst {ast} {
    set ir {}
    foreach node $ast {
        switch [dict get $node type] {
            title   { lappend ir [dict create type heading \
                          content [list [dict create type text \
                              text [dict get $node text]]] \
                          meta [dict create level 1]] }
            para    { lappend ir [dict create type paragraph \
                          content [list [dict create type text \
                              text [dict get $node text]]] meta {}] }
        }
    }
    return $ir
}
```

The result can then be checked with `docir::validate` and handed to any
sink.

## Writing a sink

A sink iterates over the flat IR and produces the output format. Because
the IR is flat, a loop with a `switch` over `type` suffices — no tree
recursion needed:

```tcl
namespace eval myrender {}

proc myrender::render {ir} {
    set out ""
    foreach node $ir {
        switch [dict get $node type] {
            heading   { append out ">> " [text [dict get $node content]] "\n" }
            paragraph { append out [text [dict get $node content]] "\n\n" }
            default   { }   ;# ignore unknown types, do not abort
        }
    }
    return $out
}
```

The `default` branch ignores unknown types instead of aborting — this is
the defensive baseline of the IR.

## The hub promise

As soon as the new source yields valid IR, all existing sinks serve it —
PDF, HTML, and the rest. As soon as the new sink processes the IR, it
benefits from all sources. It is exactly this cut at the [intermediate
representation]{.index} that keeps the number of converters small.
