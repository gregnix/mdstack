#!/usr/bin/env wish
# Demo: mdsearch – Full-text search with highlight
#
# Eigene Module aus dem Repo (Tests laufen aus dem Repo)
if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}


package require Tk

set dir [file dirname [file normalize [info script]]]
package require mdstack::parser 0.2
package require mdstack::viewer 0.3
package require mdstack::search 0.1

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
    set n [mdstack::search::next .v]
    updateStatus
}
ttk::button .top.prev -text "↑" -width 3 -command {
    set n [mdstack::search::prev .v]
    updateStatus
}
ttk::button .top.clear -text "✕" -width 3 -command {
    mdstack::search::clearHighlight .v
    set ::searchTerm ""
    set ::statusText ""
}
ttk::label .top.status -textvariable ::statusText -width 15

pack .top.lbl .top.entry .top.find .top.prev .top.next .top.clear .top.status \
    -side left -padx 2 -pady 4
pack .top -side top -fill x

bind .top.entry <Return> doSearch

proc doSearch {} {
    set matches [mdstack::search::find .v $::searchTerm]
    if {[llength $matches] > 0} {
        mdstack::search::next .v
    }
    updateStatus
}

proc updateStatus {} {
    set total [mdstack::search::count .v]
    set cur [mdstack::search::current .v]
    if {$total > 0} {
        set ::statusText "$cur / $total"
    } elseif {$::searchTerm ne ""} {
        set ::statusText "No matches"
    } else {
        set ::statusText ""
    }
}

# Viewer
mdstack::viewer::create .v
pack .v -fill both -expand 1

set ast [mdstack::parser::parse $md]
mdstack::viewer::render .v $ast

wm title . "mdsearch Demo"
wm geometry . 700x600
focus .top.entry
