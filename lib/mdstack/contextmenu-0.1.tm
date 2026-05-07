# mdcontextmenu-0.1.tm
# ------------------------------------------------------------
# Context menus for Markdown editor
# ------------------------------------------------------------
# Provides right-click menus for:
# - Editor (mdtext)
# - Outline (mdoutline)
#

package require Tk
package require mdstack::uicontextmenu 0.1

package provide mdstack::contextmenu 0.1

namespace eval mdstack::contextmenu {
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

proc mdstack::contextmenu::createEditorMenu {} {
    variable editorMenu
    
    if {$editorMenu ne "" && [winfo exists $editorMenu]} {
        return $editorMenu
    }
    
    set editorMenu [mdstack::uicontextmenu::create .mdEditorContextMenu -dynamic 1]
    
    # Update handler for dynamic entries
    mdstack::uicontextmenu::setUpdateHandler $editorMenu [list mdstack::contextmenu::_updateEditorMenu]
    
    return $editorMenu
}

proc mdstack::contextmenu::_updateEditorMenu {} {
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
    mdstack::uicontextmenu::addItem $editorMenu "Cut" \
        -command [list mdstack::contextmenu::_cut $currentEditor] \
        -accelerator "Ctrl+X" \
        -state [expr {$hasSelection ? "normal" : "disabled"}]
    
    mdstack::uicontextmenu::addItem $editorMenu "Copy" \
        -command [list mdstack::contextmenu::_copy $currentEditor] \
        -accelerator "Ctrl+C" \
        -state [expr {$hasSelection ? "normal" : "disabled"}]
    
    mdstack::uicontextmenu::addItem $editorMenu "Insert" \
        -command [list mdstack::contextmenu::_paste $currentEditor] \
        -accelerator "Ctrl+V"
    
    mdstack::uicontextmenu::addSeparator $editorMenu
    
    # Format group
    mdstack::uicontextmenu::addItem $editorMenu "Fett" \
        -command [list $currentEditor wrap "**"] \
        -accelerator "Ctrl+B"
    
    mdstack::uicontextmenu::addItem $editorMenu "Kursiv" \
        -command [list $currentEditor wrap "*"] \
        -accelerator "Ctrl+I"
    
    mdstack::uicontextmenu::addItem $editorMenu "Code" \
        -command [list $currentEditor wrap "`"] \
        -accelerator "Ctrl+`"
    
    mdstack::uicontextmenu::addItem $editorMenu "Durchgestrichen" \
        -command [list $currentEditor wrap "~~"]
    
    mdstack::uicontextmenu::addSeparator $editorMenu
    
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
    
    mdstack::uicontextmenu::addSeparator $editorMenu
    
    # Insert group
    mdstack::uicontextmenu::addItem $editorMenu "Insert Link..." \
        -command [list mdstack::contextmenu::_insertLink $currentEditor] \
        -accelerator "Ctrl+K"
    
    mdstack::uicontextmenu::addItem $editorMenu "Insert Image..." \
        -command [list mdstack::contextmenu::_insertImage $currentEditor]
    
    mdstack::uicontextmenu::addItem $editorMenu "Insert Table..." \
        -command [list mdstack::contextmenu::_insertTable $currentEditor]
    
    mdstack::uicontextmenu::addItem $editorMenu "Code-Block" \
        -command [list $currentEditor codeblock]
    
    mdstack::uicontextmenu::addItem $editorMenu "Horizontale Linie" \
        -command [list mdstack::contextmenu::_insertHR $currentEditor]
    
    mdstack::uicontextmenu::addSeparator $editorMenu
    
    # Auswahl-Gruppe
    mdstack::uicontextmenu::addItem $editorMenu "Select All" \
        -command [list mdstack::contextmenu::_selectAll $currentEditor] \
        -accelerator "Ctrl+A"
}

proc mdstack::contextmenu::attachToEditor {editor} {
    variable editorMenu
    variable currentEditor
    
    createEditorMenu
    
    # $editor is the widget path, use for bind
    # ($editor text returns the command, not the path)
    
    # Right-click binding
    bind $editor <Button-3> [list mdstack::contextmenu::_showEditorMenu $editor %X %Y]
    
    # For macOS
    bind $editor <Control-Button-1> [list mdstack::contextmenu::_showEditorMenu $editor %X %Y]
}

proc mdstack::contextmenu::_showEditorMenu {editor x y} {
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

proc mdstack::contextmenu::createOutlineMenu {} {
    variable outlineMenu
    
    if {$outlineMenu ne "" && [winfo exists $outlineMenu]} {
        return $outlineMenu
    }
    
    set outlineMenu [mdstack::uicontextmenu::create .mdOutlineContextMenu -dynamic 1]
    
    mdstack::uicontextmenu::setUpdateHandler $outlineMenu [list mdstack::contextmenu::_updateOutlineMenu]
    
    return $outlineMenu
}

proc mdstack::contextmenu::_updateOutlineMenu {} {
    variable outlineMenu
    variable currentOutline
    
    $outlineMenu delete 0 end
    
    # Delete submenu if it exists
    catch {destroy $outlineMenu.level}
    
    if {$currentOutline eq "" || ![winfo exists $currentOutline]} {
        return
    }
    
    set tree [mdstack::outline::dispatch $currentOutline tree]
    set sel [$tree selection]
    set hasSelection [expr {$sel ne ""}]
    
    mdstack::uicontextmenu::addItem $outlineMenu "Go to Heading" \
        -command [list mdstack::outline::gotoSelection $currentOutline] \
        -state [expr {$hasSelection ? "normal" : "disabled"}]
    
    mdstack::uicontextmenu::addSeparator $outlineMenu
    
    # Change heading level
    set levelMenu [menu $outlineMenu.level -tearoff 0]
    for {set i 1} {$i <= 6} {incr i} {
        $levelMenu add command -label "Ebene $i (H$i)" \
            -command [list mdstack::contextmenu::_changeHeadingLevel $currentOutline $i]
    }
    $outlineMenu add cascade -label "Change Level" -menu $levelMenu \
        -state [expr {$hasSelection ? "normal" : "disabled"}]
    
    mdstack::uicontextmenu::addSeparator $outlineMenu
    
    mdstack::uicontextmenu::addItem $outlineMenu "Alle aufklappen" \
        -command [list mdstack::contextmenu::_expandAll $currentOutline]
    
    mdstack::uicontextmenu::addItem $outlineMenu "Alle zuklappen" \
        -command [list mdstack::contextmenu::_collapseAll $currentOutline]
    
    mdstack::uicontextmenu::addSeparator $outlineMenu
    
    mdstack::uicontextmenu::addItem $outlineMenu "Aktualisieren" \
        -command [list mdstack::outline::refresh $currentOutline]
}

proc mdstack::contextmenu::attachToOutline {outline} {
    variable outlineMenu
    variable currentOutline
    
    createOutlineMenu
    
    set tree [mdstack::outline::dispatch $outline tree]
    
    bind $tree <Button-3> [list mdstack::contextmenu::_showOutlineMenu $outline %X %Y %x %y]
    bind $tree <Control-Button-1> [list mdstack::contextmenu::_showOutlineMenu $outline %X %Y %x %y]
}

proc mdstack::contextmenu::_showOutlineMenu {outline X Y x y} {
    variable outlineMenu
    variable currentOutline
    
    set currentOutline $outline
    set tree [mdstack::outline::dispatch $outline tree]
    
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

proc mdstack::contextmenu::_cut {editor} {
    set t [$editor text]
    if {![catch {$t index sel.first}]} {
        clipboard clear
        clipboard append [$t get sel.first sel.last]
        $t delete sel.first sel.last
    }
}

proc mdstack::contextmenu::_copy {editor} {
    set t [$editor text]
    if {![catch {$t index sel.first}]} {
        clipboard clear
        clipboard append [$t get sel.first sel.last]
    }
}

proc mdstack::contextmenu::_paste {editor} {
    set t [$editor text]
    if {![catch {set text [clipboard get]}]} {
        if {![catch {$t index sel.first}]} {
            $t delete sel.first sel.last
        }
        $t insert insert $text
    }
}

proc mdstack::contextmenu::_selectAll {editor} {
    set t [$editor text]
    $t tag add sel 1.0 end-1c
}

proc mdstack::contextmenu::_insertLink {editor} {
    set url [_inputDialog "Insert Link" "URL:"]
    if {$url eq ""} return
    
    set text [_inputDialog "Link-Text" "Text:" $url]
    if {$text eq ""} {set text $url}
    
    set t [$editor text]
    $t insert insert "\[$text\]($url)"
}

proc mdstack::contextmenu::_insertImage {editor} {
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

proc mdstack::contextmenu::_insertTable {editor} {
    set cols [_inputDialog "Tabelle" "Spalten:" "3"]
    if {$cols eq "" || ![string is integer $cols]} return
    
    set rows [_inputDialog "Tabelle" "Zeilen:" "3"]
    if {$rows eq "" || ![string is integer $rows]} return
    
    $editor table $cols $rows
}

proc mdstack::contextmenu::_insertHR {editor} {
    set t [$editor text]
    $t insert insert "\n---\n"
}

# ============================================================
# Outline-Aktionen
# ============================================================

proc mdstack::contextmenu::_changeHeadingLevel {outline newLevel} {
    set tree [mdstack::outline::dispatch $outline tree]
    set sel [$tree selection]
    if {$sel eq ""} return
    
    set values [$tree item $sel -values]
    if {[llength $values] == 0} return
    
    set idx [lindex $values 0]
    set editor [mdstack::outline::dispatch $outline editor]
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
    mdstack::outline::refresh $outline
}

proc mdstack::contextmenu::_expandAll {outline} {
    set tree [mdstack::outline::dispatch $outline tree]
    foreach item [$tree children {}] {
        _expandItem $tree $item
    }
}

proc mdstack::contextmenu::_expandItem {tree item} {
    $tree item $item -open 1
    foreach child [$tree children $item] {
        _expandItem $tree $child
    }
}

proc mdstack::contextmenu::_collapseAll {outline} {
    set tree [mdstack::outline::dispatch $outline tree]
    foreach item [$tree children {}] {
        _collapseItem $tree $item
    }
}

proc mdstack::contextmenu::_collapseItem {tree item} {
    $tree item $item -open 0
    foreach child [$tree children $item] {
        _collapseItem $tree $child
    }
}

# ============================================================
# Hilfs-Dialog
# ============================================================

proc mdstack::contextmenu::_inputDialog {title prompt {default ""}} {
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
    
    set ::mdstack::contextmenu::_dialogResult ""
    
    ttk::frame $w.f.btns
    pack $w.f.btns -fill x
    
    ttk::button $w.f.btns.ok -text "OK" -command {
        set ::mdstack::contextmenu::_dialogResult [.mdcontextmenu_input.f.entry get]
        destroy .mdcontextmenu_input
    }
    ttk::button $w.f.btns.cancel -text "Abbrechen" -command {
        set ::mdstack::contextmenu::_dialogResult ""
        destroy .mdcontextmenu_input
    }
    pack $w.f.btns.ok $w.f.btns.cancel -side left -padx 5
    
    bind $w.f.entry <Return> {.mdcontextmenu_input.f.btns.ok invoke}
    bind $w <Escape> {.mdcontextmenu_input.f.btns.cancel invoke}
    
    focus $w.f.entry
    grab set $w
    tkwait window $w
    
    return $::mdstack::contextmenu::_dialogResult
}
