#!/usr/bin/env wish
# Minimaler onclick Test

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require Tk
package require mdparser 0.2
package require mdmodel 0.1
package require mdviewer 0.3

wm title . "onclick Test"

# Handler
proc myClick {x y index tags lineText} {
    puts "CLICK: x=$x y=$y index=$index tags=$tags"
    puts "  Line: $lineText"
}

# Viewer
set v [mdviewer::create .v -onclick myClick]
pack $v -fill both -expand 1

# Markdown
set ast [mdparser::parse "# Test\n\nKlick mich!"]
set doc [mdmodel::new $ast]
mdviewer::renderModel $v $doc

# Debug: check tags
puts "=== DEBUG ==="
set t [mdviewer::widget $v]
puts "Widget: $t"
puts "State: [$t cget -state]"
puts "Tags at 1.0: [$t tag names 1.0]"
puts "Tags at 2.0: [$t tag names 2.0]"
puts "Tag bindings for clickable: [$t tag bind clickable]"
puts "==="
