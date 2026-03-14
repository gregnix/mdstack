#!/usr/bin/env wish
# mdtext-demo.tcl
# Demonstrates mdtext-Widget Features isoliert
# - Smart Return
# - Tab/Shift-Tab
# - Format-Operationen
# - Context menu (right-click)

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require Tk
package require mdtext 0.1
package require uicontextmenu 0.1
package require mdcontextmenu 0.1

wm title . "mdtext Widget Demo"
wm geometry . 800x600

# --- Toolbar ---
ttk::frame .toolbar
pack .toolbar -fill x -pady 2

ttk::button .toolbar.bold -text "Bold" -width 6 -command {$editor wrap "**"}
ttk::button .toolbar.italic -text "Italic" -width 6 -command {$editor wrap "*"}
ttk::button .toolbar.code -text "Code" -width 6 -command {$editor wrap "`"}
ttk::separator .toolbar.sep1 -orient vertical
ttk::button .toolbar.h1 -text "H1" -width 4 -command {$editor heading 1}
ttk::button .toolbar.h2 -text "H2" -width 4 -command {$editor heading 2}
ttk::button .toolbar.h3 -text "H3" -width 4 -command {$editor heading 3}
ttk::separator .toolbar.sep2 -orient vertical
ttk::button .toolbar.list -text "• Liste" -width 8 -command {$editor prefix "- "}
ttk::button .toolbar.quote -text "> Quote" -width 8 -command {$editor prefix "> "}
ttk::button .toolbar.checkbox -text "☐ Task" -width 8 -command {$editor checkbox}
ttk::separator .toolbar.sep3 -orient vertical
ttk::button .toolbar.codeblock -text "```" -width 6 -command {$editor codeblock tcl}
ttk::button .toolbar.table -text "Table" -width 8 -command {$editor table 3 3}

pack .toolbar.bold .toolbar.italic .toolbar.code -side left -padx 1
pack .toolbar.sep1 -side left -padx 4 -fill y
pack .toolbar.h1 .toolbar.h2 .toolbar.h3 -side left -padx 1
pack .toolbar.sep2 -side left -padx 4 -fill y
pack .toolbar.list .toolbar.quote .toolbar.checkbox -side left -padx 1
pack .toolbar.sep3 -side left -padx 4 -fill y
pack .toolbar.codeblock .toolbar.table -side left -padx 1

# --- Editor ---
ttk::frame .editorframe
pack .editorframe -fill both -expand 1 -padx 5 -pady 5

set editor [mdtext::create .editorframe.text -width 80 -height 30]

# Features aktivieren
$editor enableFeature smartReturn
$editor enableFeature indent

# Attach context menu (right-click)
mdcontextmenu::attachToEditor $editor

# Scrollbar
ttk::scrollbar .editorframe.sb -orient vertical -command [list [mdtext::_t $editor] yview]
[mdtext::_t $editor] configure -yscrollcommand [list .editorframe.sb set]

pack .editorframe.sb -side right -fill y
pack $editor -side left -fill both -expand 1

# --- Statusbar ---
ttk::frame .status
ttk::label .status.line -text "Line: 1" -width 15
ttk::label .status.type -text "Typ: text" -width 20
ttk::label .status.mod -text "" -width 15
pack .status.line .status.type .status.mod -side left -padx 5
pack .status -fill x -side bottom

# --- Status Update ---
proc updateStatus {} {
    global editor
    
    # Check if editor still exists
    if {![winfo exists $editor]} {
        return
    }
    
    # Zeilennummer
    set pos [$editor index insert]
    set line [lindex [split $pos .] 0]
    .status.line configure -text "Line: $line"
    
    # Zeilen-Typ
    set type [$editor lineType]
    .status.type configure -text "Typ: $type"
    
    # Modified
    if {[$editor modified]} {
        .status.mod configure -text "\[MODIFIED\]"
    } else {
        .status.mod configure -text ""
    }
    
    after 200 updateStatus
}
updateStatus

# --- Initial Content ---
$editor set {# mdtext Demo

Willkommen zum **mdtext** Widget!

## Smart Return

Probiere diese Features:

- Press Return at end of this line
- Die Liste wird automatisch fortgesetzt
- Leere Liste beendet durch Return

1. Numbered list
2. Funktioniert auch
3. Mit automatischer Nummerierung

## Task Lists

- [ ] Place cursor in checkbox and press Space
- [x] Diese ist erledigt

## Tab/Shift-Tab

- Press Tab to indent
  - So wie hier
    - Oder hier
- Shift-Tab outdents

## Format-Operationen

Selektiere Text und klicke auf **Bold**, *Italic* oder `Code`.

> Blockquote
> Funktioniert auch

---

*Ende der Demo*
}

# Cursor am Anfang
$editor mark set insert 1.0
