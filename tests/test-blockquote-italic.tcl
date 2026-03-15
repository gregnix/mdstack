#!/usr/bin/env wish
# Test for blockquote italic formatting

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require Tk
package require mdparser 0.2
package require mdmodel 0.1
package require mdviewer 0.3

set md {# Test Blockquote

> This is a simple quote without formatting.

> This is a quote with *italic* text.

> This is a quote with **bold** text.

> This is a quote with ***bold and italic*** text.
}

set ast [mdparser::parse $md]
set doc [mdmodel::new $ast]

wm title . "Blockquote Italic Test"
wm geometry . 600x400

set v [mdviewer::create .v]
pack $v -fill both -expand 1

mdviewer::renderModel $v $doc

puts "Test window opened. Check italic formatting in blockquotes."
