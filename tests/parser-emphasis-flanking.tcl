#!/usr/bin/env tclsh
# parser-emphasis-flanking.tcl - emphasis flanking (whitespace rule)
#
# A '*' delimiter may open emphasis only if it is not followed by whitespace,
# and may close only if it is not preceded by whitespace (the whitespace part of
# CommonMark's left/right-flanking rules). Guards against regressing into the
# old "any *...*  is emphasis" behaviour.

if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}
package require tcltest
namespace import ::tcltest::*
package require mdstack::parser

proc types {md} {
    set ts {}
    foreach i [mdstack::parser::parseInlines $md] { lappend ts [dict get $i type] }
    return $ts
}
proc hasEmph {md} { expr {("emphasis" in [types $md]) || ("strong" in [types $md])} }

# --- flanking: these must NOT become emphasis -----------------------------
test flank-1.1 {space after opening star} -body { hasEmph {a * foo bar*} } -result 0
test flank-1.2 {space before closing star} -body { hasEmph {*foo *} } -result 0
test flank-1.3 {spaces on both sides} -body { hasEmph {a * b *} } -result 0
test flank-1.4 {leading-space run} -body { hasEmph {* foo*} } -result 0

# --- punctuation flanking -------------------------------------------------
test flank-1.5 {punct-led run after a word does not open} -body { hasEmph {a*"foo"*} } -result 0
test flank-1.6 {intraword star emphasis is allowed (CommonMark)} -body {
    types {foo*bar*baz}
} -result {text emphasis text}
test flank-1.7 {punct-led run at line start opens} -body { types {*(foo)*} } -result emphasis

# --- normal emphasis must keep working ------------------------------------
test flank-2.1 {simple emphasis} -body { types {*em*} } -result emphasis
test flank-2.2 {simple strong} -body { types {**bold**} } -result strong
test flank-2.3 {emphasis mid text} -body { types {a *b* c} } -result {text emphasis text}
test flank-2.4 {two strong runs are not merged into one} -body {
    set t [types {**first** and **second**}]
    list [lindex $t 0] [lindex $t 2]
} -result {strong strong}
test flank-2.5 {emphasis content may contain spaces} -body { types {*foo bar baz*} } -result emphasis
test flank-2.6 {bold italic triple} -body { types {***bi***} } -result strong

cleanupTests
