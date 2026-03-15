#!/usr/bin/env wish
# Test for context tags (strong_q, strong_t)

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require Tk
package require mdparser 0.2
package require mdmodel 0.1
package require mdviewer 0.3

set md {# Kontext-Tags Test

## Blockquote with formatting

> Normal text in blockquote.
> 
> Text with **bold** text.
> 
> Text with *italic* text.
> 
> Text with ***bold and italic*** text.

## Table with formatting

| Feature | Status | Hinweis |
|---------|--------|---------|
| **Bold** | ✓ | Should be bold |
| *Italic* | ✓ | Should be italic |
| ***Bold+Italic*** | ✓ | Should be both |
| `Code` | ✓ | Should be monospace |

## Kombinationen

> Blockquote with **bold** text and `code`.
}

set ast [mdparser::parse $md]
set doc [mdmodel::new $ast]

wm title . "Kontext-Tags Test"
wm geometry . 700x500

set ctx_v [mdviewer::create .ctx_v]
pack $ctx_v -fill both -expand 1

mdviewer::renderModel $ctx_v $doc

puts "Test window opened."
puts "Please check:"
puts "  - Blockquote: **bold** should be bold AND italic"
puts "  - Table: **bold** should be bold AND monospace"
