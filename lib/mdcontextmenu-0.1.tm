# mdcontextmenu-0.1.tm
# (c) 2026 Gregor Ebbing -- MIT License (see LICENSE)
# ------------------------------------------------------------
# Context menus for Markdown editor
# ------------------------------------------------------------
# Provides right-click menus for:
# - Editor (mdtext)
# - Outline (mdoutline)
#

package require Tk
package require uicontextmenu 0.1

package provide mdcontextmenu 0.1

namespace eval mdcontextmenu {
    # Public API
    namespace export createEditorMenu createOutlineMenu attachToEditor attachToOutline
    # Exported for tests
    namespace export _copy _cut _paste _selectAll
    variable editorMenu ""
    variable outlineMenu ""
    variable currentEditor ""
    variable currentOutline ""
}

# ============================================================
# Editor context menu
# ============================================================

proc mdcontextmenu::createEditorMenu {} {
    variable editorMenu
    
    if {$editorMenu ne "" && [winfo exists $editorMenu]} {
        return $editorMenu
    }
    
    set editorMenu [uicontextmenu::create .mdEditorContextMenu -dynamic 1]
    
    # Update handler for dynamic entries
    uicontextmenu::setUpdateHandler $editorMenu [list mdcontextmenu::_updateEditorMenu]
    
    return $editorMenu
}

proc mdcontextmenu::_updateEditorMenu {} {
    variable editorMenu
    variable currentEditor
    
    # Clear menu
    $editorMenu delete 0 end
    
    # Delete submenus if they exist
    catch {destroy $editorMenu.heading}
    catch {destroy $editorMenu.list}
    
    if {$currentEditor eq "" || ![winfo exists $currentEditor]} {
        return
    }
    
    set t [$currentEditor widget]
    set hasSelection [expr {[catch {$t index sel.first}] == 0}]
    
    # Edit group
    uicontextmenu::addItem $editorMenu "Cut" \
        -command [list mdcontextmenu::_cut $currentEditor] \
        -accelerator "Ctrl+X" \
        -state [expr {$hasSelection ? "normal" : "disabled"}]
    
    uicontextmenu::addItem $editorMenu "Copy" \
        -command [list mdcontextmenu::_copy $currentEditor] \
        -accelerator "Ctrl+C" \
        -state [expr {$hasSelection ? "normal" : "disabled"}]
    
    uicontextmenu::addItem $editorMenu "Insert" \
        -command [list mdcontextmenu::_paste $currentEditor] \
        -accelerator "Ctrl+V"
    
    uicontextmenu::addSeparator $editorMenu
    
    # Format group
    uicontextmenu::addItem $editorMenu "Fett" \
        -command [list $currentEditor wrap "**"] \
        -accelerator "Ctrl+B"
    
    uicontextmenu::addItem $editorMenu "Kursiv" \
        -command [list $currentEditor wrap "*"] \
        -accelerator "Ctrl+I"
    
    uicontextmenu::addItem $editorMenu "Code" \
        -command [list $currentEditor wrap "`"] \
        -accelerator "Ctrl+`"
    
    uicontextmenu::addItem $editorMenu "Durchgestrichen" \
        -command [list $currentEditor wrap "~~"]
    
    uicontextmenu::addSeparator $editorMenu
    
    # Headings submenu
    set headingMenu [menu $editorMenu.heading -tearoff 0]
    $headingMenu add command -label "H1" -command [list $currentEditor heading 1] -accelerator "Ctrl+1"
    $headingMenu add command -label "H2" -command [list $currentEditor heading 2] -accelerator "Ctrl+2"
    $headingMenu add command -label "H3" -command [list $currentEditor heading 3] -accelerator "Ctrl+3"
    $headingMenu add command -label "H4" -command [list $currentEditor heading 4]
    $headingMenu add command -label "H5" -command [list $currentEditor heading 5]
    $headingMenu add command -label "H6" -command [list $currentEditor heading 6]
    $editorMenu add cascade -label "Heading" -menu $headingMenu
    
    # List submenu
    set listMenu [menu $editorMenu.list -tearoff 0]
    $listMenu add command -label "Bullet List" -command [list $currentEditor prefix "- "]
    $listMenu add command -label "Numbered" -command [list $currentEditor prefix "1. "]
    $listMenu add command -label "Checkbox" -command [list $currentEditor checkbox]
    $listMenu add separator
    $listMenu add command -label "Quote" -command [list $currentEditor prefix "> "]
    $editorMenu add cascade -label "Liste / Zitat" -menu $listMenu
    
    uicontextmenu::addSeparator $editorMenu
    
    # Insert group
    uicontextmenu::addItem $editorMenu "Insert Link..." \
        -command [list mdcontextmenu::_insertLink $currentEditor] \
        -accelerator "Ctrl+K"
    
    uicontextmenu::addItem $editorMenu "Insert Image..." \
        -command [list mdcontextmenu::_insertImage $currentEditor]
    
    uicontextmenu::addItem $editorMenu "Insert Table..." \
        -command [list mdcontextmenu::_insertTable $currentEditor]
    
    uicontextmenu::addItem $editorMenu "Code-Block" \
        -command [list $currentEditor codeblock]
    
    uicontextmenu::addItem $editorMenu "Horizontale Linie" \
        -command [list mdcontextmenu::_insertHR $currentEditor]
    
    uicontextmenu::addSeparator $editorMenu
    
    # Auswahl-Gruppe
    uicontextmenu::addItem $editorMenu "Select All" \
        -command [list mdcontextmenu::_selectAll $currentEditor] \
        -accelerator "Ctrl+A"
}

proc mdcontextmenu::attachToEditor {editor} {
    variable editorMenu
    variable currentEditor
    
    createEditorMenu
    
    # $editor is the widget path, use for bind
    # ($editor text returns the command, not the path)
    
    # Right-click binding
    bind $editor <Button-3> [list mdcontextmenu::_showEditorMenu $editor %X %Y]
    
    # For macOS
    bind $editor <Control-Button-1> [list mdcontextmenu::_showEditorMenu $editor %X %Y]
}

proc mdcontextmenu::_showEditorMenu {editor x y} {
    variable editorMenu
    variable currentEditor
    
    set currentEditor $editor
    
    # Update-Handler aufrufen
    _updateEditorMenu
    
    # Show menu
    tk_popup $editorMenu $x $y
}

# ============================================================
# Outline context menu
# ============================================================

proc mdcontextmenu::createOutlineMenu {} {
    variable outlineMenu
    
    if {$outlineMenu ne "" && [winfo exists $outlineMenu]} {
        return $outlineMenu
    }
    
    set outlineMenu [uicontextmenu::create .mdOutlineContextMenu -dynamic 1]
    
    uicontextmenu::setUpdateHandler $outlineMenu [list mdcontextmenu::_updateOutlineMenu]
    
    return $outlineMenu
}

proc mdcontextmenu::_updateOutlineMenu {} {
    variable outlineMenu
    variable currentOutline
    
    $outlineMenu delete 0 end
    
    # Delete submenu if it exists
    catch {destroy $outlineMenu.level}
    
    if {$currentOutline eq "" || ![winfo exists $currentOutline]} {
        return
    }
    
    set tree [mdoutline::dispatch $currentOutline tree]
    set sel [$tree selection]
    set hasSelection [expr {$sel ne ""}]
    
    uicontextmenu::addItem $outlineMenu "Go to Heading" \
        -command [list mdoutline::gotoSelection $currentOutline] \
        -state [expr {$hasSelection ? "normal" : "disabled"}]
    
    uicontextmenu::addSeparator $outlineMenu
    
    # Change heading level
    set levelMenu [menu $outlineMenu.level -tearoff 0]
    for {set i 1} {$i <= 6} {incr i} {
        $levelMenu add command -label "Ebene $i (H$i)" \
            -command [list mdcontextmenu::_changeHeadingLevel $currentOutline $i]
    }
    $outlineMenu add cascade -label "Change Level" -menu $levelMenu \
        -state [expr {$hasSelection ? "normal" : "disabled"}]
    
    uicontextmenu::addSeparator $outlineMenu
    
    uicontextmenu::addItem $outlineMenu "Alle aufklappen" \
        -command [list mdcontextmenu::_expandAll $currentOutline]
    
    uicontextmenu::addItem $outlineMenu "Alle zuklappen" \
        -command [list mdcontextmenu::_collapseAll $currentOutline]
    
    uicontextmenu::addSeparator $outlineMenu
    
    uicontextmenu::addItem $outlineMenu "Aktualisieren" \
        -command [list mdoutline::refresh $currentOutline]
}

proc mdcontextmenu::attachToOutline {outline} {
    variable outlineMenu
    variable currentOutline
    
    createOutlineMenu
    
    set tree [mdoutline::dispatch $outline tree]
    
    bind $tree <Button-3> [list mdcontextmenu::_showOutlineMenu $outline %X %Y %x %y]
    bind $tree <Control-Button-1> [list mdcontextmenu::_showOutlineMenu $outline %X %Y %x %y]
}

proc mdcontextmenu::_showOutlineMenu {outline X Y x y} {
    variable outlineMenu
    variable currentOutline
    
    set currentOutline $outline
    set tree [mdoutline::dispatch $outline tree]
    
    # Select item under cursor
    set item [$tree identify item $x $y]
    if {$item ne ""} {
        $tree selection set $item
    }
    
    _updateOutlineMenu
    
    tk_popup $outlineMenu $X $Y
}

# ============================================================
# Editor-Aktionen
# ============================================================

proc mdcontextmenu::_cut {editor} {
    set t [$editor text]
    if {![catch {$t index sel.first}]} {
        clipboard clear
        clipboard append [$t get sel.first sel.last]
        $t delete sel.first sel.last
    }
}

proc mdcontextmenu::_copy {editor} {
    set t [$editor text]
    if {![catch {$t index sel.first}]} {
        clipboard clear
        clipboard append [$t get sel.first sel.last]
    }
}

proc mdcontextmenu::_paste {editor} {
    set t [$editor text]
    if {![catch {set text [clipboard get]}]} {
        if {![catch {$t index sel.first}]} {
            $t delete sel.first sel.last
        }
        $t insert insert $text
    }
}

proc mdcontextmenu::_selectAll {editor} {
    set t [$editor text]
    $t tag add sel 1.0 end-1c
}

proc mdcontextmenu::_insertLink {editor} {
    set url [_inputDialog "Insert Link" "URL:"]
    if {$url eq ""} return
    
    set text [_inputDialog "Link-Text" "Text:" $url]
    if {$text eq ""} {set text $url}
    
    set t [$editor text]
    $t insert insert "\[$text\]($url)"
}

proc mdcontextmenu::_insertImage {editor} {
    set file [tk_getOpenFile \
        -title "Choose Image" \
        -filetypes {
            {"Bilder" {.png .jpg .jpeg .gif .webp .svg}}
            {"Alle" *}
        }]
    
    if {$file eq ""} return
    
    set alt [_inputDialog "Alt-Text" "Beschreibung:" [file tail $file]]
    if {$alt eq ""} {set alt "Bild"}
    
    set t [$editor text]
    $t insert insert "!\[$alt\]($file)"
}

proc mdcontextmenu::_insertTable {editor} {
    set cols [_inputDialog "Tabelle" "Spalten:" "3"]
    if {$cols eq "" || ![string is integer $cols]} return
    
    set rows [_inputDialog "Tabelle" "Zeilen:" "3"]
    if {$rows eq "" || ![string is integer $rows]} return
    
    $editor table $cols $rows
}

proc mdcontextmenu::_insertHR {editor} {
    set t [$editor text]
    $t insert insert "\n---\n"
}

# ============================================================
# Outline-Aktionen
# ============================================================

proc mdcontextmenu::_changeHeadingLevel {outline newLevel} {
    set tree [mdoutline::dispatch $outline tree]
    set sel [$tree selection]
    if {$sel eq ""} return
    
    set values [$tree item $sel -values]
    if {[llength $values] == 0} return
    
    set idx [lindex $values 0]
    set editor [mdoutline::dispatch $outline editor]
    set t [$editor text]
    
    # Get line
    set lineNum [lindex [split $idx .] 0]
    set lineStart "$lineNum.0"
    set lineEnd "$lineNum.end"
    set line [$t get $lineStart $lineEnd]
    
    # Remove old heading prefix
    set line [regsub {^#{1,6}\s*} $line ""]
    
    # Set new prefix
    set prefix [string repeat "#" $newLevel]
    set newLine "$prefix $line"
    
    # Ersetzen
    $t delete $lineStart $lineEnd
    $t insert $lineStart $newLine
    
    # Update outline
    mdoutline::refresh $outline
}

proc mdcontextmenu::_expandAll {outline} {
    set tree [mdoutline::dispatch $outline tree]
    foreach item [$tree children {}] {
        _expandItem $tree $item
    }
}

proc mdcontextmenu::_expandItem {tree item} {
    $tree item $item -open 1
    foreach child [$tree children $item] {
        _expandItem $tree $child
    }
}

proc mdcontextmenu::_collapseAll {outline} {
    set tree [mdoutline::dispatch $outline tree]
    foreach item [$tree children {}] {
        _collapseItem $tree $item
    }
}

proc mdcontextmenu::_collapseItem {tree item} {
    $tree item $item -open 0
    foreach child [$tree children $item] {
        _collapseItem $tree $child
    }
}

# ============================================================
# Hilfs-Dialog
# ============================================================

proc mdcontextmenu::_inputDialog {title prompt {default ""}} {
    set w .mdcontextmenu_input
    catch {destroy $w}
    
    toplevel $w
    wm title $w $title
    wm transient $w .
    wm resizable $w 0 0
    
    # Zentrieren
    wm withdraw $w
    update idletasks
    set x [expr {[winfo screenwidth $w]/2 - 150}]
    set y [expr {[winfo screenheight $w]/2 - 50}]
    wm geometry $w "+$x+$y"
    wm deiconify $w
    
    ttk::frame $w.f -padding 15
    pack $w.f -fill both -expand 1
    
    ttk::label $w.f.lbl -text $prompt
    ttk::entry $w.f.entry -width 40
    if {$default ne ""} {
        $w.f.entry insert 0 $default
        $w.f.entry selection range 0 end
    }
    
    pack $w.f.lbl -anchor w
    pack $w.f.entry -fill x -pady 5
    
    set ::mdcontextmenu::_dialogResult ""
    
    ttk::frame $w.f.btns
    pack $w.f.btns -fill x
    
    ttk::button $w.f.btns.ok -text "OK" -command {
        set ::mdcontextmenu::_dialogResult [.mdcontextmenu_input.f.entry get]
        destroy .mdcontextmenu_input
    }
    ttk::button $w.f.btns.cancel -text "Abbrechen" -command {
        set ::mdcontextmenu::_dialogResult ""
        destroy .mdcontextmenu_input
    }
    pack $w.f.btns.ok $w.f.btns.cancel -side left -padx 5
    
    bind $w.f.entry <Return> {.mdcontextmenu_input.f.btns.ok invoke}
    bind $w <Escape> {.mdcontextmenu_input.f.btns.cancel invoke}
    
    focus $w.f.entry
    grab set $w
    tkwait window $w
    
    return $::mdcontextmenu::_dialogResult
}
