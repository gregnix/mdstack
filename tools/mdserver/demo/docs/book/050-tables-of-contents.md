# Tables: Contents and Index

The table of contents and the subject index are both built from the IR and
are available in both main sinks.

## Table of contents

The [table of contents]{.index} is built from the headings. In PDF,
`generateToc 1` enables a leading contents page with page numbers;
`tocTitle` and `tocDepth` control title and depth. In HTML, `includeToc 1`
does the same with clickable jump targets.

The page numbers in the PDF arise from a two-pass procedure: because the
contents page shifts the following pages, the document is laid out
repeatedly until the page numbers are stable.

## Subject index

A subject [index]{.index} is built from terms marked in the text. The
marker is a bracketed span with the class `index`:

```markdown
A [coroutine]{.index} suspends a script.
```

The term stays visible in the running text and is collected at the same
time. Such a [span]{.index} may appear in any paragraph at any level,
including in sub-chapters.

In PDF, `generateIndex 1` enables the index: alphabetical, grouped by
initial letter, each term with all pages where it occurs. The page is
captured while typesetting, so it stays correct across page breaks too. In
HTML, `includeIndex 1` enables the index with links to the occurrences,
labelled with the section title.
