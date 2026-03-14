#!/usr/bin/env wish
# mdoutline-demo.tcl -- Outline panel demo
#
# Shows an editor with heading outline on the left.
# Click on heading jumps to line in editor.

set appDir [file dirname [file normalize [info script]]]
set libDir [file join [file dirname $appDir] lib]
tcl::tm::path add $libDir

package require Tk 8.6-
package require mdtext     0.1
package require mdoutline  0.1

# --- Test Document ---
set markdown {# Main Heading

Introductory text for the document.

## Installation

Tcl/Tk 8.6 is required.

### Requirements

- Linux or Windows
- Tcl/Tk 8.6+

### Download

From the official website.

## Configuration

Configuration is done via a file.

### Paths

All paths are relative to the installation directory.

### Options

Options are specified as key-value pairs.

## Usage

### First Start

The program opens with the start page.

### Editor

The editor supports Markdown with live preview.

## FAQ

Frequently asked questions.

### How do I update?

Simply download the new version.

### Where can I find help?

In the built-in documentation.
}

# --- GUI ---
wm title . "mdoutline Demo"
wm geometry . 900x600

ttk::panedwindow .pw -orient horizontal
pack .pw -fill both -expand 1

# Editor (mdtext)
set ed [mdtext::create .pw.editor]
.pw add .pw.editor -weight 1

# Outline (left)
set outline [mdoutline::create .pw.outline -editor $ed]
.pw add .pw.outline -weight 0

# Order: Outline left
.pw forget .pw.outline
.pw forget .pw.editor
.pw add .pw.outline -weight 0
.pw add .pw.editor -weight 1

# Set text
set t [mdtext::_t $ed]
$t insert end $markdown
$t mark set insert 1.0
$t see 1.0

# Fill outline
mdoutline::refresh $outline

# Update outline on changes
bind $t <KeyRelease> [list after idle [list mdoutline::refresh $outline]]

ttk::label .info -text "Click on heading in outline jumps to the line." \
    -foreground "#666666"
pack .info -fill x -padx 4 -pady 2
