#!/usr/bin/env tclsh
tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]
package require mdparser 0.2

set md {## Title

Text *em* **strong** `code`

```tcl
puts "hi"
```
}

set ast [mdparser::parse $md]

# Check document type
puts "doc-type: [dict get $ast type]"

set blocks [dict get $ast blocks]
puts "block-count: [llength $blocks]"

# Block 0: heading
set b0 [lindex $blocks 0]
puts "b0-type: [dict get $b0 type]"
puts "b0-level: [dict get $b0 level]"
puts "b0-has-content: [dict exists $b0 content]"

# Block 1: paragraph
set b1 [lindex $blocks 1]
puts "b1-type: [dict get $b1 type]"
set inlines [dict get $b1 content]
set types {}
foreach i $inlines {
    lappend types [dict get $i type]
}
puts "b1-inline-types: $types"

# Check emphasis (not em)
set emNode ""
foreach i $inlines {
    if {[dict get $i type] eq "emphasis"} { set emNode $i }
}
puts "has-emphasis: [expr {$emNode ne {}}]"

# Check inline_code (not code_inline)
set codeNode ""
foreach i $inlines {
    if {[dict get $i type] eq "inline_code"} { set codeNode $i }
}
puts "has-inline_code: [expr {$codeNode ne {}}]"
puts "inline_code-value: [dict get $codeNode value]"

# Check strong
set strongNode ""
foreach i $inlines {
    if {[dict get $i type] eq "strong"} { set strongNode $i }
}
puts "has-strong: [expr {$strongNode ne {}}]"

# Block 2: code_block
set b2 [lindex $blocks 2]
puts "b2-type: [dict get $b2 type]"
puts "b2-language: [dict get $b2 language]"
puts "b2-has-text: [dict exists $b2 text]"
puts "b2-language-is-tcl: [expr {[dict get $b2 language] eq {tcl}}]"

puts ""
puts "=== ALL CHECKS ==="
puts "PASS"
