#!/usr/bin/env wish
# Test for blockquote italic formatting

# Eigene Module aus dem Repo (Tests laufen aus dem Repo)
if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}


package require Tk
package require mdstack::parser 0.2
package require mdstack::model 0.1
package require mdstack::viewer 0.3

set md {# Test Blockquote

> This is a simple quote without formatting.

> This is a quote with *italic* text.

> This is a quote with **bold** text.

> This is a quote with ***bold and italic*** text.
}

set ast [mdstack::parser::parse $md]
set doc [mdstack::model::new $ast]

wm title . "Blockquote Italic Test"
wm geometry . 600x400

set v [mdstack::viewer::create .v]
pack $v -fill both -expand 1

mdstack::viewer::renderModel $v $doc

puts "Test window opened. Check italic formatting in blockquotes."
