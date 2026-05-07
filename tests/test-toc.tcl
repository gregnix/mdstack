#!/usr/bin/env tclsh
# Test TOC-Problem

# Eigene Module aus dem Repo (Tests laufen aus dem Repo)
if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}


package require mdstack::parser 0.2
package require mdstack::pdf 0.2

set markdown {
# Heading 1

## Heading 2

Text hier.

### Heading 3

Mehr Text.
}

set ast [mdstack::parser::parse $markdown]

# Check AST structure
puts "=== AST-Struktur ==="
if {[dict exists $ast blocks]} {
    foreach block [dict get $ast blocks] {
        if {[dict exists $block type]} {
            set type [dict get $block type]
            puts "Block-Typ: $type"
            if {$type eq "heading"} {
                puts "  Level: [dict get $block level]"
                puts "  Alle Keys: [dict keys $block]"
                if {[dict exists $block content]} {
                    puts "  Inlines vorhanden: [llength [dict get $block content]]"
                    foreach inline [dict get $block content] {
                        puts "    Inline: [dict get $inline type]"
                    }
                } else {
                    puts "  KEINE INLINES!"
                }
            }
        }
    }
}

# TOC testen
puts "\n=== TOC-Test ==="
mdstack::pdf::export $ast "test-toc.pdf" -toc 1 -debug 1
