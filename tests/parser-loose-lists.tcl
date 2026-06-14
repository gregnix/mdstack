#!/usr/bin/env tclsh
# parser-loose-lists.tcl - loose lists / multi-paragraph list items (0.5.0)

if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}
package require tcltest
namespace import ::tcltest::*
package require mdstack::parser

proc firstBlock {md} { lindex [dict get [mdstack::parser::parse $md] blocks] 0 }
proc itemParaCount {lst i} {
    set it [lindex [dict get $lst items] $i]
    set n 0
    foreach b [dict get $it blocks] { if {[dict get $b type] eq "paragraph"} { incr n } }
    return $n
}
proc looseFlag {lst} { expr {[dict exists $lst loose] ? [dict get $lst loose] : 0} }

test loose-1.1 {blank line inside an item -> two paragraphs} -body {
    set l [firstBlock "- one\n\n  two"]
    list [dict get $l type] [llength [dict get $l items]] [itemParaCount $l 0] [looseFlag $l]
} -result {list 1 2 1}

test loose-1.2 {tight list stays one paragraph per item, not loose} -body {
    set l [firstBlock "- a\n- b"]
    list [llength [dict get $l items]] [itemParaCount $l 0] [looseFlag $l]
} -result {2 1 0}

test loose-1.3 {blank between items -> loose flag, item count unchanged} -body {
    set l [firstBlock "- a\n\n- b"]
    list [llength [dict get $l items]] [looseFlag $l]
} -result {2 1}

test loose-1.4 {lazy continuation (no blank) stays one paragraph} -body {
    set l [firstBlock "- one\n  cont\n- two"]
    list [itemParaCount $l 0] [looseFlag $l]
} -result {1 0}

test loose-1.5 {ordered loose item has two paragraphs} -body {
    set l [firstBlock "1. first\n\n   more\n2. second"]
    list [dict get $l style] [itemParaCount $l 0] [looseFlag $l]
} -result {ordered 2 1}

test loose-1.6 {4-space indent after list stays a separate code block} -body {
    set blocks [dict get [mdstack::parser::parse "- item one\n- item two\n\n    code block\n"] blocks]
    list [dict get [lindex $blocks 0] type] [dict get [lindex $blocks 1] type]
} -result {list code_block}

cleanupTests
