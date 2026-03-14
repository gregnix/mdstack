#!/usr/bin/env wish
# mdstack-editor-demo.tcl
# Demonstrates: mdtext (Editor) + mdviewer (Preview) Integration
#
# Architecture:
#   mdtext    = Editor widget (edit text only)
#   mdviewer  = Preview widget (render only)
#   mdparser  = Parser (Text → AST)
#   mdmodel   = Model (AST → Doc)
#   mdcontextmenu = right-click menu

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require Tk
package require mdtext 0.1
package require mdparser 0.2
package require mdmodel 0.1
package require mdviewer 0.3
package require uicontextmenu 0.1
package require mdcontextmenu 0.1

# --- GUI Setup ---
wm title . "mdstack Editor Demo"
wm geometry . 1000x700

# Hauptframe mit PanedWindow (Editor | Preview)
ttk::panedwindow .paned -orient horizontal
pack .paned -fill both -expand 1

# --- Editor-Pane (links) ---
ttk::frame .paned.editor
ttk::label .paned.editor.label -text "Editor (mdtext)" -font {TkDefaultFont 10 bold}
pack .paned.editor.label -fill x -pady 2

# mdtext erstellen
set editor [mdtext::create .paned.editor.text -width 50 -height 30]
$editor enableFeature smartReturn
$editor enableFeature indent

# Context menu (right-click)
mdcontextmenu::attachToEditor $editor

# Scrollbar for editor
ttk::scrollbar .paned.editor.sb -orient vertical -command [list [mdtext::_t $editor] yview]
[mdtext::_t $editor] configure -yscrollcommand [list .paned.editor.sb set]

pack .paned.editor.sb -side right -fill y
pack $editor -side left -fill both -expand 1

# --- Preview-Pane (right) ---
ttk::frame .paned.preview
ttk::label .paned.preview.label -text "Preview (mdviewer)" -font {TkDefaultFont 10 bold}
pack .paned.preview.label -fill x -pady 2

set preview [mdviewer::create .paned.preview.viewer -root [file dirname [info script]]]
pack $preview -fill both -expand 1

# Add panes
.paned add .paned.editor -weight 1
.paned add .paned.preview -weight 1

# --- Update-Funktion ---
proc updatePreview {} {
    global editor preview
    
    # Get text from editor
    set markdown [$editor get]
    
    # Parse and render
    set ast [mdparser::parse $markdown]
    set doc [mdmodel::new $ast]
    
    # Update preview
    mdviewer::renderModel $preview $doc
}

# --- onchange Callback ---
$editor onchange updatePreview

# --- Initial Content ---
$editor set {# Welcome to mdstack Editor

This is a demo of the **mdstack** integration:
- `mdtext` = Editor widget
- `mdviewer` = Preview widget
- `mdparser` = Parser

## Features

### Smart Return
Press Return in a list:
- Item 1
- Item 2

### Task Lists
- [ ] Task open
- [x] Task done

### Tables

| Column 1 | Column 2 |
|----------|----------|
| Row 1  | Value 1   |
| Row 2  | Value 2   |

### Blockquote

> This is a quote.
> It can span multiple lines.

### Code

```tcl
proc hello {} {
    puts "Hello World"
}
```

---

*Edit text on the left and see the live preview on the right!*
}

# Initiales Preview
updatePreview

# --- Statusbar ---
ttk::frame .status
ttk::label .status.info -text "mdtext 0.1 | mdviewer 0.3 | mdparser 0.2"
pack .status.info -side left -padx 5
pack .status -fill x -side bottom

# Modified indicator
proc updateStatus {} {
    global editor
    if {![winfo exists $editor]} {
        return
    }
    if {[$editor modified]} {
        .status.info configure -text "mdtext 0.1 | mdviewer 0.3 | mdparser 0.2 | \[MODIFIED\]"
    } else {
        .status.info configure -text "mdtext 0.1 | mdviewer 0.3 | mdparser 0.2"
    }
    after 1000 updateStatus
}
updateStatus
