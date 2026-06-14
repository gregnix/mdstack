#!/usr/bin/env tclsh
# parser-link-features.tcl - link/image: empty text/url, title variants, <url>

if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}
package require tcltest
namespace import ::tcltest::*
package require mdstack::parser

proc first {md} { lindex [mdstack::parser::parseInlines $md] 0 }
proc fld {md k} { set i [first $md]; expr {[dict exists $i $k] ? [dict get $i $k] : "-"} }

test link-empty-text {empty link text is allowed} -body {
    list [dict get [first {[](http://x)}] type] [fld {[](http://x)} url]
} -result {link http://x}
test link-empty-url {empty destination is allowed} -body {
    list [dict get [first {[t]()}] type] [fld {[t]()} url]
} -result {link {}}
test link-title-single {single-quoted title} -body { fld {[t](u 'st')} title } -result st
test link-title-paren {parenthesised title} -body { fld {[t](u (pt))} title } -result pt
test link-title-double {double-quoted title still works} -body { fld {[t](u "dt")} title } -result dt
test link-angle-url {angle-bracketed dest with space} -body { fld {[t](<a b>)} url } -result {a b}
test image-title {inline image keeps title} -body {
    list [dict get [first {![a](i.png "cap")}] type] [fld {![a](i.png "cap")} title]
} -result {image cap}

# --- reference images: plain-text alt + shortcut form -----------------------
proc imgIn {md} {
    set ast [mdstack::parser::parse $md]
    foreach blk [dict get $ast blocks] {
        if {[dict exists $blk content]} {
            foreach n [dict get $blk content] {
                if {[dict get $n type] eq "image"} { return $n }
            }
        }
    }
    return {}
}
test refimage-collapsed {collapsed ref image, alt is plain text} -body {
    dict get [imgIn "!\[foo *bar*\]\[\]\n\n\[foo *bar*\]: t.jpg \"x\""] alt
} -result {foo bar}
test refimage-full {full ref image resolves + plain-text alt} -body {
    set n [imgIn "!\[foo *bar*\]\[fb\]\n\n\[FB\]: t.jpg"]
    list [dict get $n url] [dict get $n alt]
} -result {t.jpg {foo bar}}
test refimage-shortcut {shortcut ref image ![alt] resolves} -body {
    set n [imgIn "!\[foo *bar*\]\n\n\[foo *bar*\]: t.jpg"]
    list [dict get $n type] [dict get $n alt]
} -result {image {foo bar}}

# --- autolinks: arbitrary URI schemes ---------------------------------------
test autolink-scheme-irc {irc: scheme autolink} -body { fld {<irc://a.b:2/c>} url } -result {irc://a.b:2/c}
test autolink-scheme-custom {custom scheme autolink} -body {
    fld {<made-up-scheme://foo,bar>} url
} -result {made-up-scheme://foo,bar}
test autolink-mailto-uri {MAILTO: kept as URI, not lowercased} -body {
    fld {<MAILTO:FOO@BAR.BAZ>} url
} -result {MAILTO:FOO@BAR.BAZ}
test autolink-email {plain email autolink still adds mailto:} -body {
    fld {<foo@bar.baz>} url
} -result {mailto:foo@bar.baz}
test autolink-https {https angle autolink still works} -body {
    fld {<https://example.com>} url
} -result {https://example.com}

cleanupTests
