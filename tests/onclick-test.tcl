#!/usr/bin/env wish
# Minimaler onclick Test

# Eigene Module aus dem Repo (Tests laufen aus dem Repo)
if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}


package require Tk
package require mdstack::parser 0.2
package require mdstack::model 0.1
package require mdstack::viewer 0.3

wm title . "onclick Test"

# Handler
proc myClick {x y index tags lineText} {
    puts "CLICK: x=$x y=$y index=$index tags=$tags"
    puts "  Line: $lineText"
}

# Viewer
set v [mdstack::viewer::create .v -onclick myClick]
pack $v -fill both -expand 1

# Markdown
set ast [mdstack::parser::parse "# Test\n\nKlick mich!"]
set doc [mdstack::model::new $ast]
mdstack::viewer::renderModel $v $doc

# Debug: check tags
puts "=== DEBUG ==="
set t [mdstack::viewer::widget $v]
puts "Widget: $t"
puts "State: [$t cget -state]"
puts "Tags at 1.0: [$t tag names 1.0]"
puts "Tags at 2.0: [$t tag names 2.0]"
puts "Tag bindings for clickable: [$t tag bind clickable]"
puts "==="
