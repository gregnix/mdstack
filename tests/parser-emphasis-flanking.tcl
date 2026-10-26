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
# CommonMark: *** resolves to <em><strong>...</strong></em> (delimiter stack, 0.7.0)
test flank-2.6 {bold italic triple} -body { types {***bi***} } -result emphasis

# --- nested emphasis: closing run search (since 0.6.5) -----------------------
#
# The lazy regexp took the FIRST '*' after the opener as the closer. In
# "*italic **bold** text*" that is the opening star of "**bold**"; it fails
# right-flanking and the whole run collapsed to literal text.

proc emphKinds {md} {
    set para [lindex [dict get [mdstack::parser::parse $md] blocks] 0]
    set out {}
    foreach inl [dict get $para content] { lappend out [dict get $inl type] }
    return $out
}
proc firstInline {md} {
    set para [lindex [dict get [mdstack::parser::parse $md] blocks] 0]
    return [lindex [dict get $para content] 0]
}

test em-nested-strong-in-em {strong inside emphasis} -body {
    emphKinds {*italic **bold** text*}
} -result {emphasis}

test em-nested-strong-in-em-inner {the strong survives inside} -body {
    set em [firstInline {*italic **bold** text*}]
    set kinds {}
    foreach k [dict get $em content] { lappend kinds [dict get $k type] }
    set kinds
} -result {text strong text}

test em-nested-em-in-strong {emphasis inside strong} -body {
    set st [firstInline {**strong *em* here**}]
    list [dict get $st type] [lmap k [dict get $st content] { dict get $k type }]
} -result {strong {text emphasis text}}

test em-both {*** stays bold+italic (CommonMark nesting: em outside)} -body {
    set n [firstInline {***both***}]
    list [dict get $n type] [dict get [lindex [dict get $n content] 0] type]
} -result {emphasis strong}

test em-trailing-run {*foo*** closes at the first star of the trailing run} -body {
    set n [firstInline {*foo***}]
    list [dict get $n type] [dict get [lindex [dict get $n content] 0] value]
} -result {emphasis foo}

test em-unbalanced-inner {*a**b* keeps the unbalanced ** literal} -body {
    set n [firstInline {*a**b*}]
    dict get $n type
} -result {emphasis}

# --- what only the delimiter stack can express (0.7.0) -----------------------

test em-opener-needs-flanking {opener followed by space is literal} -body {
    emphKinds {** foo bar**}
} -result {text}

test em-rule-of-three {a**"foo"** stays literal (rule of 3)} -body {
    emphKinds {a**"foo"**}
} -result {text}

test em-intraword-underscore {_foo_bar_baz_ is one emphasis} -body {
    set n [firstInline {_foo_bar_baz_}]
    list [dict get $n type] [dict get [lindex [dict get $n content] 0] value]
} -result {emphasis foo_bar_baz}

test em-nested-parens {*(*foo*)* nests} -body {
    set n [firstInline {*(*foo*)*}]
    list [dict get $n type] [lmap k [dict get $n content] { dict get $k type }]
} -result {emphasis {text emphasis text}}

test em-underscore-nested-parens {_(_foo_)_ nests} -body {
    dict get [firstInline {_(_foo_)_}] type
} -result {emphasis}

# A line break counts as whitespace for flanking. The joined paragraph stores
# it as "\x00SB"; "**%**" at the start of a continuation line stayed literal
# (Tcl manual, clock.md: "Zeichen außer\n**%**, durchsetzt ...").
test em-after-softbreak-punct {**%** at the start of a continuation line} -body {
    set p [lindex [dict get [mdstack::parser::parse "x\n**%** c"] blocks] 0]
    lmap n [dict get $p content] { dict get $n type }
} -result {text softbreak strong text}

test em-before-softbreak-punct {**%** at the end of a line} -body {
    set p [lindex [dict get [mdstack::parser::parse "a **%**\nb"] blocks] 0]
    lmap n [dict get $p content] { dict get $n type }
} -result {text strong softbreak text}

test em-underscore-softbreak-intraword {foo_ / bar stays literal across a break} -body {
    set p [lindex [dict get [mdstack::parser::parse "foo_\nbar"] blocks] 0]
    lmap n [dict get $p content] { dict get $n type }
} -result {text softbreak text}

# --- three stars switch emphasis like Pandoc (0.9.1) ------------------------
#
# n2md --tip700 and man2markdown.tcl write nroff \fIa\fBb\fR as *a***b**.
# Pandoc reads <em>a</em><strong>b</strong>; plain CommonMark left "**b**"
# literal (letter before, punctuation after: the run may not open).

proc shape {md} {
    set out {}
    foreach n [mdstack::parser::parseInlines $md] {
        set t [dict get $n type]
        if {$t eq "text"} { lappend out [list text [dict get $n value]]; continue }
        set txt ""
        foreach c [dict get $n content] {
            if {[dict exists $c value]} { append txt [dict get $c value] }
        }
        lappend out [list $t $txt]
    }
    return $out
}
test switch-1.1 {italic then bold, punctuation after} -body {
    shape {under *ZIPFS\_VOLUME***/app** as}
} -result {{text {under }} {emphasis ZIPFS_VOLUME} {strong /app} {text { as}}}
test switch-1.2 {alternating bold and italic} -body {
    shape {**libtcl\_***major***\_***minor***.zip**}
} -result {{strong libtcl_} {emphasis major} {strong _} {emphasis minor} {strong .zip}}
test switch-1.3 {bold then italic} -body {
    shape {**a***b* end}
} -result {{strong a} {emphasis b} {text { end}}}
test switch-1.4 {after a parenthesis} -body {
    shape {*TK\_OPTION\_VAR(***type**)}
} -result {{emphasis TK_OPTION_VAR(} {strong type} {text )}}
test switch-1.5 {intraword bold italic stays nested (no open run before)} -body {
    lmap n [mdstack::parser::parseInlines {foo***bar***baz}] { dict get $n type }
} -result {text emphasis text}
test switch-1.6 {stars between digits stay literal} -body {
    shape {2***3 and 4 * 5}
} -result {{text {2***3 and 4 * 5}}}

cleanupTests
