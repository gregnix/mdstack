#!/usr/bin/env tclsh
# viewer.tcl - Tests for mdstack::viewer (Tk text-widget renderer)
#
# Covers creation/config, rendering of headings/paragraphs/links, both table
# modes, the link callback, font sizing, and -- as a regression test for the
# frame-mode table wheel bug -- that an embedded table frame forwards the mouse
# wheel to the viewer text widget.

if {![info exists ::_setup_done]} {
    # in front: an installed mdstack (TCLLIBPATH, ~/lib/...) of the same
    # version must not shadow the one under test
    set ::auto_path [linsert $::auto_path 0 \
        [file normalize [file join [file dirname [info script]] .. lib]]]
    set ::_setup_done 1
}

package require tcltest
namespace import ::tcltest::*

if {[catch {package require Tk}]} {
    puts "Skipping viewer tests (no Tk)"
    return
}
package require mdstack::parser
package require mdstack::viewer

wm withdraw .

test viewer-0.1 {the viewer under test is the one of this repository} -body {
    set lib [file normalize [file join [file dirname [info script]] .. lib]]
    set src [package ifneeded mdstack::viewer [package present mdstack::viewer]]
    expr {[string first $lib $src] >= 0 ? "ok" : $src}
} -result ok

proc ast {md} { mdstack::parser::parse $md }

# --- creation / config -----------------------------------------------------
test viewer-1.1 {create returns the path} -body {
    mdstack::viewer::create .v
} -result {.v} -cleanup {destroy .v}

test viewer-1.2 {widget returns the inner text widget} -body {
    mdstack::viewer::create .v
    set t [mdstack::viewer::widget .v]
    list [winfo exists $t] [winfo class $t]
} -result {1 Text} -cleanup {destroy .v}

test viewer-1.3 {default tablemode is text} -body {
    mdstack::viewer::create .v
    mdstack::viewer::cget .v -tablemode
} -result {text} -cleanup {destroy .v}

test viewer-1.4 {configure -tablemode is read back by cget} -body {
    mdstack::viewer::create .v
    mdstack::viewer::configure .v -tablemode frame
    mdstack::viewer::cget .v -tablemode
} -result {frame} -cleanup {destroy .v}

# --- rendering -------------------------------------------------------------
test viewer-2.1 {render puts heading + paragraph text into the widget} -body {
    mdstack::viewer::create .v
    mdstack::viewer::render .v [ast "# Title\n\nHello world."]
    set t [mdstack::viewer::widget .v]
    set txt [$t get 1.0 end]
    list [string match {*Title*} $txt] [string match {*Hello world.*} $txt]
} -result {1 1} -cleanup {destroy .v}

test viewer-2.2 {render is repeatable (clear between renders)} -body {
    mdstack::viewer::create .v
    mdstack::viewer::render .v [ast "first"]
    mdstack::viewer::render .v [ast "second"]
    set txt [[mdstack::viewer::widget .v] get 1.0 end]
    list [string match {*second*} $txt] [string match {*first*} $txt]
} -result {1 0} -cleanup {destroy .v}

test viewer-2.3 {link text is rendered and a link tag exists} -body {
    mdstack::viewer::create .v
    mdstack::viewer::render .v [ast "see \[the site\](http://example.com)."]
    set t [mdstack::viewer::widget .v]
    set hasLinkTag 0
    foreach tg [$t tag names] { if {[string match {*link*} $tg]} { set hasLinkTag 1 } }
    list [string match {*the site*} [$t get 1.0 end]] $hasLinkTag
} -result {1 1} -cleanup {destroy .v}

# --- tables: text vs frame mode -------------------------------------------
set tableMd "| H1 | H2 |\n|----|----|\n| a  | b  |\n"

test viewer-3.1 {text-mode table embeds no window, shows cell text} -body {
    mdstack::viewer::create .v -tablemode text
    mdstack::viewer::render .v [ast $::tableMd]
    set t [mdstack::viewer::widget .v]
    list [llength [$t window names]] [string match {*H1*} [$t get 1.0 end]]
} -result {0 1} -cleanup {destroy .v}

test viewer-3.2 {frame-mode table embeds a window} -body {
    mdstack::viewer::create .v -tablemode frame
    mdstack::viewer::render .v [ast $::tableMd]
    set t [mdstack::viewer::widget .v]
    expr {[llength [$t window names]] >= 1}
} -result {1} -cleanup {destroy .v}

# Regression: the embedded frame (and its children) must forward the wheel to
# the text widget, otherwise scrolling stops while the pointer is over a table.
test viewer-3.3 {frame-mode table forwards mouse wheel to the text widget} -body {
    mdstack::viewer::create .v -tablemode frame
    mdstack::viewer::render .v [ast $::tableMd]
    set t   [mdstack::viewer::widget .v]
    set win [lindex [$t window names] 0]
    expr {[bind $win <MouseWheel>] ne "" || [bind $win <Button-4>] ne ""}
} -result {1} -cleanup {destroy .v}

# --- link callback ---------------------------------------------------------
test viewer-4.1 {dispatchLink invokes the -onlink callback with the url} -body {
    set ::__lk ""
    mdstack::viewer::create .v -onlink {apply {{u} {set ::__lk $u}}}
    mdstack::viewer::dispatchLink .v "http://example.com/page"
    set ::__lk
} -result {http://example.com/page} -cleanup {destroy .v; unset -nocomplain ::__lk}

test viewer-4.2 {anchor links (#x) do not reach the onlink callback} -body {
    set ::__lk none
    mdstack::viewer::create .v -onlink {apply {{u} {set ::__lk $u}}}
    mdstack::viewer::dispatchLink .v "#somewhere"
    set ::__lk
} -result {none} -cleanup {destroy .v; unset -nocomplain ::__lk}

# --- font sizing -----------------------------------------------------------
test viewer-5.1 {setFontSize is reflected by cget -fontsize} -body {
    mdstack::viewer::create .v
    mdstack::viewer::setFontSize .v 14
    mdstack::viewer::cget .v -fontsize
} -result {14} -cleanup {destroy .v}

# --- lists: nesting and hanging indent ----------------------------------------
# margins in effect on a text line: {lmargin1 lmargin2} of the list indent
# tag with the highest priority there ([tag names] lists lowest first)
proc listMargins {t line} {
    set m {}
    foreach tg [$t tag names $line.0] {
        if {[string match listind_* $tg]} {
            set m [list [$t tag cget $tg -lmargin1] [$t tag cget $tg -lmargin2]]
        }
    }
    return $m
}

test viewer-6.1 {nested list items are indented deeper} -body {
    mdstack::viewer::create .v
    mdstack::viewer::render .v [ast "- a\n  - b\n    - c\n- d\n"]
    set t [mdstack::viewer::widget .v]
    list [lmap l {1 2 3 4} { lindex [listMargins $t $l] 0 }] \
        [lmap l {1 2 3 4} { $t get $l.0 }]
} -result [list {4 26 48 4} [list \u2022 \u25e6 \u25aa \u2022]] -cleanup {destroy .v}

test viewer-6.2 {wrapped list lines continue under the text} -body {
    mdstack::viewer::create .v
    mdstack::viewer::render .v [ast "- a\n1. b\n"]
    set t [mdstack::viewer::widget .v]
    set f [$t cget -font]
    list [expr {[lindex [listMargins $t 1] 1] - [lindex [listMargins $t 1] 0]
                == [font measure $f "\u2022 "]}] \
         [expr {[lindex [listMargins $t 3] 1] - [lindex [listMargins $t 3] 0]
                == [font measure $f "1. "]}]
} -result {1 1} -cleanup {destroy .v}

test viewer-6.3 {no empty line after a nested list} -body {
    mdstack::viewer::create .v
    mdstack::viewer::render .v [ast "- a\n  - b\n- c\n"]
    set t [mdstack::viewer::widget .v]
    string trimright [$t get 1.0 end] \n
} -result "\u2022 a\n\u25e6 b\n\u2022 c" -cleanup {destroy .v}

test viewer-6.4 {clear drops the list indent tags} -body {
    mdstack::viewer::create .v
    mdstack::viewer::render .v [ast "- a\n"]
    mdstack::viewer::clear .v
    set t [mdstack::viewer::widget .v]
    lsearch -all -inline -glob [$t tag names] listind_*
} -result {} -cleanup {destroy .v}

# --- frame tables --------------------------------------------------------------
test viewer-7.1 {default -tableframemax is 100} -body {
    mdstack::viewer::create .v
    mdstack::viewer::cget .v -tableframemax
} -result {100} -cleanup {destroy .v}

test viewer-7.2 {the wheel helper is looked up once, not per cell} -body {
    unset -nocomplain ::mdstack::viewer::wheelHelper
    mdstack::viewer::create .v -tablemode frame
    mdstack::viewer::render .v [ast "| a | b |\n|---|---|\n| 1 | 2 |\n"]
    info exists ::mdstack::viewer::wheelHelper
} -result {1} -cleanup {destroy .v}

# --- text-mode tables: long cells wrap ------------------------------------------
test viewer-8.1 {a long cell wraps, nothing is cut off} -body {
    mdstack::viewer::create .v
    set long "eins zwei drei vier fuenf sechs sieben acht neun zehn elf zwoelf dreizehn"
    mdstack::viewer::render .v [ast "| a | b |\n|---|---|\n| x | $long |\n"]
    set t [mdstack::viewer::widget .v]
    set txt [$t get 1.0 end]
    set words [regexp -all -inline {[a-z]+} $txt]
    list [expr {[string first \u2026 $txt] < 0}] \
        [expr {[lsearch -exact $words dreizehn] >= 0}] \
        [expr {[llength [split [string trim $txt] \n]] > 3}]
} -result {1 1 1} -cleanup {destroy .v}

test viewer-8.2 {a short cell keeps its formatting} -body {
    mdstack::viewer::create .v
    mdstack::viewer::render .v [ast "| a |\n|---|\n| **fett** |\n"]
    set t [mdstack::viewer::widget .v]
    set r [$t search fett 1.0]
    expr {[lsearch -glob [$t tag names $r] *bold*] >= 0
          || [lsearch -glob [$t tag names $r] *strong*] >= 0}
} -result {1} -cleanup {destroy .v}

test viewer-8.3 {wrapText breaks at spaces and splits long words} -body {
    list [mdstack::viewer::wrapText "aa bb cc" 5] \
        [mdstack::viewer::wrapText "abcdefgh" 3]
} -result {{{aa bb} cc} {abc def gh}}

# --- frame tables: text and links in one cell --------------------------------
test viewer-9.1 {a link next to text in a cell stays clickable} -body {
    set ::__lk ""
    mdstack::viewer::create .v -tablemode frame -onlink {apply {{u} {set ::__lk $u}}}
    pack .v
    mdstack::viewer::render .v [ast "| a |\n|---|\n| siehe \[X\](http://example.com/x) dort |\n"]
    update
    set t [mdstack::viewer::widget .v]
    set cell [lindex [winfo children [lindex [$t window names] 0]] end]
    set link ""
    foreach l [winfo children $cell] {
        if {[$l cget -text] eq "X"} { set link $l }
    }
    # the main window is withdrawn here, so run the binding directly
    uplevel #0 [bind $link <Button-1>]
    list [lmap l [winfo children $cell] { $l cget -text }] $::__lk
} -result {{{siehe } X { dort}} http://example.com/x} -cleanup {destroy .v; unset -nocomplain ::__lk}

# --- headings and table of contents ------------------------------------------------
test viewer-10.1 {headings lists level, anchor and text} -body {
    mdstack::viewer::create .v
    mdstack::viewer::render .v [ast "# Eins\n\ntext\n\n## Zwei **b**\n"]
    mdstack::viewer::headings .v
} -result {{1 eins Eins} {2 zwei-b {Zwei b}}} -cleanup {destroy .v}

test viewer-10.2 {toc fills a tree nested by level; selecting jumps} -body {
    mdstack::viewer::create .v
    ttk::treeview .tr -show tree
    pack .v .tr
    mdstack::viewer::render .v [ast "# A\n\n## B\n\n### C\n\n## D\n"]
    set n [mdstack::viewer::toc .v .tr]
    .tr selection set d
    update
    list $n [.tr children {}] [.tr children a] [.tr children b] \
        [expr {[lsearch [mdstack::viewer::anchors .v] d] >= 0}]
} -result {4 a {b d} c 1} -cleanup {destroy .v .tr}

test viewer-10.3 {clear empties the headings} -body {
    mdstack::viewer::create .v
    mdstack::viewer::render .v [ast "# A\n"]
    mdstack::viewer::clear .v
    mdstack::viewer::headings .v
} -result {} -cleanup {destroy .v}

cleanupTests
