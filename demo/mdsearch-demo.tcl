#!/usr/bin/env wish
# Demo: mdsearch – Full-text search with highlight
#
package require Tk

set dir [file dirname [file normalize [info script]]]
tcl::tm::path add [file join $dir .. lib]

package require mdparser 0.2
package require mdviewer 0.3
package require mdsearch 0.1

set md {# Tcl/Tk Reference

## Introduction

Tcl (Tool Command Language) is a scripting language developed by John Ousterhout.
Tcl is known for its simple syntax and
integration with the Tk toolkit.

## Basics

### Variables

In Tcl, variables are set with `set`:

```
set name "Hello"
set count 42
```

### Lists

Tcl has built-in **list support**:

```
set colors {red green blue}
lappend colors yellow
```

### Dictionaries

Since Tcl 8.5, **dictionaries** are available as native data structure:

```
set person [dict create name "Alice" age 30]
dict get $person name
```

## Tk Widgets

### Button

A button is created in Tcl as follows:

```
button .b -text "Click me" -command {puts "Hello"}
pack .b
```

### Label

Labels display text:

```
label .l -text "Tcl is great"
```

### Entry

Eingabefelder in Tk:

```
entry .e -textvariable myVar
```

## Zusammenfassung

Tcl and Tk together form a powerful system for
GUI-Anwendungen und Automatisierung.
}

# --- GUI ---
set ::searchTerm ""
set ::statusText ""
ttk::frame .top
ttk::label .top.lbl -text "Search:"
ttk::entry .top.entry -width 30 -textvariable ::searchTerm
ttk::button .top.find -text "Find" -command doSearch
ttk::button .top.next -text "↓" -width 3 -command {
    set n [mdsearch::next .v]
    updateStatus
}
ttk::button .top.prev -text "↑" -width 3 -command {
    set n [mdsearch::prev .v]
    updateStatus
}
ttk::button .top.clear -text "✕" -width 3 -command {
    mdsearch::clearHighlight .v
    set ::searchTerm ""
    set ::statusText ""
}
ttk::label .top.status -textvariable ::statusText -width 15

pack .top.lbl .top.entry .top.find .top.prev .top.next .top.clear .top.status \
    -side left -padx 2 -pady 4
pack .top -side top -fill x

bind .top.entry <Return> doSearch

proc doSearch {} {
    set matches [mdsearch::find .v $::searchTerm]
    if {[llength $matches] > 0} {
        mdsearch::next .v
    }
    updateStatus
}

proc updateStatus {} {
    set total [mdsearch::count .v]
    set cur [mdsearch::current .v]
    if {$total > 0} {
        set ::statusText "$cur / $total"
    } elseif {$::searchTerm ne ""} {
        set ::statusText "No matches"
    } else {
        set ::statusText ""
    }
}

# Viewer
mdviewer::create .v
pack .v -fill both -expand 1

set ast [mdparser::parse $md]
mdviewer::render .v $ast

wm title . "mdsearch Demo"
wm geometry . 700x600
focus .top.entry
