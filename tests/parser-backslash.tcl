#!/usr/bin/env tclsh
# parser-backslash.tcl - backslash escapes any ASCII punctuation

if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}
package require tcltest
namespace import ::tcltest::*
package require mdstack::parser

proc plain {md} {
    set out ""
    foreach n [mdstack::parser::parseInlines $md] {
        if {[dict exists $n value]} { append out [dict get $n value] }
    }
    return $out
}
proc types {md} {
    set t {}
    foreach n [mdstack::parser::parseInlines $md] { lappend t [dict get $n type] }
    return $t
}

test bs-all-punct {backslash escapes the full ASCII punctuation set} -body {
    plain {\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\:\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~}
} -result {!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~}
test bs-extra-punct {previously-missing escapes now work} -body {
    plain {\$\%\<\>\:\;\?\@\/\^}
} -result {$%<>:;?@/^}
test bs-non-punct {backslash before a letter stays literal} -body {
    plain {\a\b\1}
} -result {\a\b\1}
test bs-star-no-emphasis {escaped star is not emphasis (all text, no emphasis)} -body {
    lsort -unique [types {\*not\*}]
} -result {text}

cleanupTests
