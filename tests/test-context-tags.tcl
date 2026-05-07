#!/usr/bin/env wish
# Test for context tags (strong_q, strong_t)

# Eigene Module aus dem Repo (Tests laufen aus dem Repo)
if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}


package require Tk
package require mdstack::parser 0.2
package require mdstack::model 0.1
package require mdstack::viewer 0.3

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

set ast [mdstack::parser::parse $md]
set doc [mdstack::model::new $ast]

wm title . "Kontext-Tags Test"
wm geometry . 700x500

set ctx_v [mdstack::viewer::create .ctx_v]
pack $ctx_v -fill both -expand 1

mdstack::viewer::renderModel $ctx_v $doc

puts "Test window opened."
puts "Please check:"
puts "  - Blockquote: **bold** should be bold AND italic"
puts "  - Table: **bold** should be bold AND monospace"
