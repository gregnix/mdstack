#!/usr/bin/env tclsh
# viewer.tcl - Tests for mdstack::viewer (Tk text-widget renderer)
#
# Covers creation/config, rendering of headings/paragraphs/links, both table
# modes, the link callback, font sizing, and -- as a regression test for the
# frame-mode table wheel bug -- that an embedded table frame forwards the mouse
# wheel to the viewer text widget.

if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
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

cleanupTests
