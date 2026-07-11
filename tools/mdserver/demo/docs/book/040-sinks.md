# Sinks

A [sink]{.index} produces an output format from the IR. All sinks work
exclusively on the IR and are therefore independent of the original
source.

## PDF

`docir::pdf` renders to PDF via pdf4tcl and pdf4tcllib.

```tcl
docir::pdf::render $ir out.pdf [dict create \
    title "My Document" paper a4 footer "%p"]
```

The sink supports, among other things, a table of contents with page
numbers and a subject index (see the next chapter). It relies on the
Unicode-safe text and font handling of pdf4tcllib.

## HTML

`docir::html` renders to self-contained HTML with embedded CSS.

```tcl
set html [docir::html::render $ir [dict create \
    title "My Document" includeToc 1]]
```

Headings receive their `id` as an anchor, so the table of contents and
cross-references work as clickable jump targets.

## Further sinks

Besides PDF and HTML there are other [sink]{.index}s in the docir hub,
including a Markdown sink (round-trip), an nroff sink, an SVG and a Canvas
sink, a Tk renderer sink, and the tile sinks for cheat-sheet-style
layouts. Since they all work on the same IR, every source is automatically
available to each of these sinks.
