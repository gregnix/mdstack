#!/usr/bin/env wish
# mdtheme-demo.tcl -- Color scheme demo for mdviewer
#
# Shows a viewer with theme switcher (Light/Dark/Solarized).
# Demonstrates mdtheme::activate, mdtheme::color, mdtheme::applyToViewer.

set appDir [file dirname [file normalize [info script]]]
set libDir [file join [file dirname $appDir] lib]
tcl::tm::path add $libDir

package require Tk 8.6-
package require mdparser  0.2
package require mdmodel   0.1
package require mdviewer   0.3
package require mdtheme    0.1

# --- Test Document ---
set markdown {# Theme Demo

This document shows the three color schemes.

## Code Block with Syntax Highlighting

```tcl
proc greet {name} {
    # Print greeting
    set msg "Hello $name"
    puts $msg
    return -code ok $msg
}

greet "World"
```

## Table

| Name | Type | Status |
|---|---|---|
| Alpha | Library | ok |
| Beta | App | in progress |

## Formatting

**Bold**, *italic*, `inline code` and ~~strikethrough~~.

> A blockquote with **bold** emphasis
> spanning multiple lines.

## Links

An [internal link](demo.md) and an [external link](https://tcl.tk).

---

*End of demo*
}

# --- GUI ---
wm title . "mdtheme Demo"
wm geometry . 800x600

ttk::frame .tb
pack .tb -fill x -padx 4 -pady 4

ttk::label .tb.l -text "Farbschema:"
pack .tb.l -side left -padx 4

foreach tn [mdtheme::names] {
    set label [dict get [mdtheme::theme $tn] name]
    ttk::radiobutton .tb.t_$tn -text $label \
        -variable ::currentTheme -value $tn \
        -command [list applyTheme $tn]
    pack .tb.t_$tn -side left -padx 4
}

set ::currentTheme "hell"

# Viewer
mdviewer::create .viewer -fontsize 11 -tablemode frame
pack .viewer -fill both -expand 1

# Parse + Render
set ast [mdparser::parse $markdown]
set doc [mdmodel::new $ast]
mdviewer::renderModel .viewer $doc

proc applyTheme {name} {
    mdtheme::activate $name
    mdtheme::applyToViewer .viewer

    # Re-render so syntax highlighting uses theme colors
    set ast [mdparser::parse $::markdown]
    set doc [mdmodel::new $ast]
    mdviewer::renderModel .viewer $doc
}
