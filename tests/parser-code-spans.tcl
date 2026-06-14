#!/usr/bin/env tclsh
# parser-code-spans.tcl - CommonMark code spans: run length, space strip, NL->space

if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}
package require tcltest
namespace import ::tcltest::*
package require mdstack::parser

proc codeVal {md} {
    set i [lindex [mdstack::parser::parseInlines $md] 0]
    if {[dict get $i type] ne "inline_code"} { return "NOTCODE:[dict get $i type]" }
    return [dict get $i value]
}

test cs-basic {single backtick} -body { codeVal {`code`} } -result {code}
test cs-double-inner-backtick {double backtick span keeps a single backtick} -body {
    codeVal {`` foo ` bar ``}
} -result {foo ` bar}
test cs-triple {triple backtick span} -body { codeVal {```a`b```} } -result {a`b}
test cs-strip-space {one leading+trailing space stripped} -body {
    codeVal {`  ``  `}
} -result { `` }
test cs-all-spaces {all-space content is preserved (not stripped)} -body {
    codeVal {`  `}
} -result {  }

cleanupTests
