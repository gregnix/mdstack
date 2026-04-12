# mdstack-0.1.tm
# ============================================================
# Markdown Stack Orchestrator
# ============================================================
# Manages the context stack for Markdown documents.
# Connects Editor, Preview und Datenquelle (z.B. noteskit).
#
# Architektur:
#   mdstack (dieser Orchestrator)
#       ├── Editor - connected via setEditorAPI (Callbacks)
#       ├── Preview - connected via setPreviewAPI (Callback)
#       └── Datenquelle (noteskit) - via push/pop
#
# WICHTIG: mdstack kennt KEINE konkreten Module!
#          mdstack ruft NIEMALS Widget-Methoden auf!
#          Only via the defined callbacks.
#


package provide mdstack 0.1

namespace eval mdstack {
    # Public API
    namespace export push pop current currentId currentText currentSource
    namespace export history clear goto
    namespace export setEditorAPI editorGetText editorSetText editorClear editorIsModified
    namespace export setPreviewAPI updatePreview
    namespace export onchange onmodified onsave
    namespace export modified save
    namespace export size isEmpty index entries
    
    # Stack: list of entries {id text source modified}
    variable stack {}
    
    # Currenter Index (-1 = leer)
    variable currentIndex -1
    
    # Editor-API (nur Callbacks, KEINE Widget-Referenz!)
    variable editorAPI
    array set editorAPI {
        getText    ""
        setText    ""
        clear      ""
        isModified ""
    }
    
    # Preview-API
    variable previewAPI
    array set previewAPI {
        render ""
    }
    
    # Callbacks
    variable callbacks
    array set callbacks {
        onchange   ""
        onmodified ""
        onsave     ""
    }
}

# ============================================================
# Editor-API (festgezogen, stabil)
# ============================================================
# mdstack ruft NIEMALS Widget-Methoden auf!
# Only via these defined wrappers.
# ============================================================

# setEditorAPI - Editor-Callbacks registrieren
# 
# Options:
#   -getText    SCRIPT  (Required) Returns Markdown string
#   -setText    SCRIPT  (Required) Receives text as last argument
#   -clear      SCRIPT  (Pflicht) Leert den Editor
#   -isModified SCRIPT  (Optional) Returns 0/1
#   -onchange   SCRIPT  (Optional) Registriert Change-Callback am Editor
#
# Example:
#   set editor [mdtext::create .editor]
#   mdstack::setEditorAPI \
#       -getText   [list $editor get] \
#       -setText   [list $editor set] \
#       -clear     [list $editor clear] \
#       -onchange  [list $editor onchange] \
#       -isModified [list $editor modified]
#
proc mdstack::setEditorAPI {args} {
    variable editorAPI
    
    array set opts {
        -getText    ""
        -setText    ""
        -clear      ""
        -isModified ""
        -onchange   ""
    }
    array set opts $args
    
    # Validate required fields
    if {$opts(-getText) eq ""} {
        error "mdstack::setEditorAPI: -getText ist Pflicht"
    }
    if {$opts(-setText) eq ""} {
        error "mdstack::setEditorAPI: -setText ist Pflicht"
    }
    if {$opts(-clear) eq ""} {
        error "mdstack::setEditorAPI: -clear ist Pflicht"
    }
    
    set editorAPI(getText)    $opts(-getText)
    set editorAPI(setText)    $opts(-setText)
    set editorAPI(clear)      $opts(-clear)
    set editorAPI(isModified) $opts(-isModified)
    
    # Change-Callback einrichten wenn angegeben
    if {$opts(-onchange) ne ""} {
        catch {
            uplevel #0 [list {*}$opts(-onchange) [list mdstack::_onEditorChange]]
        }
    }
    
    # Currenten Text in Editor laden falls Stack nicht leer
    _loadCurrentToEditor
}

# editorGetText - Text vom Editor holen (Wrapper)
proc mdstack::editorGetText {} {
    variable editorAPI
    
    if {$editorAPI(getText) eq ""} {
        error "mdstack: Editor API not set (call setEditorAPI first)"
    }
    return [uplevel #0 $editorAPI(getText)]
}

# editorSetText - Text im Editor setzen (Wrapper)
proc mdstack::editorSetText {text} {
    variable editorAPI
    
    if {$editorAPI(setText) eq ""} {
        error "mdstack: Editor API not set (call setEditorAPI first)"
    }
    uplevel #0 [list {*}$editorAPI(setText) $text]
}

# editorClear - Editor leeren (Wrapper)
proc mdstack::editorClear {} {
    variable editorAPI
    
    if {$editorAPI(clear) eq ""} {
        error "mdstack: Editor API not set (call setEditorAPI first)"
    }
    uplevel #0 $editorAPI(clear)
}

# editorIsModified - Modified-Status vom Editor (Wrapper)
proc mdstack::editorIsModified {} {
    variable editorAPI
    
    if {$editorAPI(isModified) eq ""} {
        return 0
    }
    return [uplevel #0 $editorAPI(isModified)]
}

# ============================================================
# Preview-API
# ============================================================

# setPreviewAPI - Preview-Callback registrieren
#
# Options:
#   -render SCRIPT  Receives $text as argument
#
proc mdstack::setPreviewAPI {args} {
    variable previewAPI
    
    array set opts {
        -render ""
    }
    array set opts $args
    
    set previewAPI(render) $opts(-render)
}

# updatePreview - Update preview
proc mdstack::updatePreview {} {
    variable previewAPI
    
    if {$previewAPI(render) eq ""} {
        return
    }
    
    set text [currentText]
    catch {uplevel #0 [list {*}$previewAPI(render) $text]}
}

# ============================================================
# Stack-Verwaltung
# ============================================================

# push - Push new entry onto stack
# Options:
#   -id      Eindeutige ID (Pflicht)
#   -text    Markdown-Text (Default: "")
#   -source  Quelle z.B. "noteskit", "file" (Default: "")
#
proc mdstack::push {args} {
    variable stack
    variable currentIndex
    
    # Defaults
    array set opts {
        -id     ""
        -text   ""
        -source ""
    }
    array set opts $args
    
    if {$opts(-id) eq ""} {
        error "mdstack::push: -id ist Pflicht"
    }
    
    # Currenten Editor-Text sichern bevor gewechselt wird
    _saveCurrentToStack
    
    # Check if ID already exists
    set idx [_findById $opts(-id)]
    if {$idx >= 0} {
        # Existiert schon - dorthin wechseln
        set currentIndex $idx
    } else {
        # New entry
        set entry [dict create \
            id       $opts(-id) \
            text     $opts(-text) \
            source   $opts(-source) \
            modified 0]
        lappend stack $entry
        set currentIndex [expr {[llength $stack] - 1}]
    }
    
    # Update editor
    _loadCurrentToEditor
    
    # Update preview
    updatePreview
    
    # Callback
    _fireCallback onchange
    
    return $opts(-id)
}

# pop - Remove top entry and switch to previous
proc mdstack::pop {} {
    variable stack
    variable currentIndex
    
    if {$currentIndex < 0} {
        return ""
    }
    
    # Get current entry
    set entry [lindex $stack $currentIndex]
    set id [dict get $entry id]
    
    # Remove
    set stack [lreplace $stack $currentIndex $currentIndex]
    
    # Index anpassen
    if {[llength $stack] == 0} {
        set currentIndex -1
        _clearEditor
    } else {
        set currentIndex [expr {min($currentIndex, [llength $stack] - 1)}]
        _loadCurrentToEditor
    }
    
    # Update preview
    updatePreview
    
    # Callback
    _fireCallback onchange
    
    return $id
}

# current - Return current entry as dict
proc mdstack::current {} {
    variable stack
    variable currentIndex
    
    if {$currentIndex < 0} {
        return {}
    }
    
    # Currenten Editor-Text holen
    _saveCurrentToStack
    
    return [lindex $stack $currentIndex]
}

# currentId - ID of current entry
proc mdstack::currentId {} {
    set entry [current]
    if {$entry eq {}} {
        return ""
    }
    return [dict get $entry id]
}

# currentText - Text of current entry
# Holt Text direkt vom Editor wenn API gesetzt
proc mdstack::currentText {} {
    variable editorAPI
    variable stack
    variable currentIndex
    
    # Direkt vom Editor holen wenn API gesetzt
    if {$editorAPI(getText) ne ""} {
        catch {
            return [editorGetText]
        }
    }
    
    # Sonst aus Stack
    if {$currentIndex < 0} {
        return ""
    }
    set entry [lindex $stack $currentIndex]
    return [dict get $entry text]
}

# currentSource - Source of current entry
proc mdstack::currentSource {} {
    set entry [current]
    if {$entry eq {}} {
        return ""
    }
    return [dict get $entry source]
}

# history - Liste aller IDs im Stack
proc mdstack::history {} {
    variable stack
    
    set result {}
    foreach entry $stack {
        lappend result [dict get $entry id]
    }
    return $result
}

# clear - Stack leeren
proc mdstack::clear {} {
    variable stack
    variable currentIndex
    
    set stack {}
    set currentIndex -1
    
    _clearEditor
    updatePreview
    _fireCallback onchange
}

# goto - Zu bestimmter ID wechseln
proc mdstack::goto {id} {
    variable stack
    variable currentIndex
    
    set idx [_findById $id]
    if {$idx < 0} {
        error "mdstack::goto: ID '$id' not found"
    }
    
    # Currenten Text sichern
    _saveCurrentToStack
    
    # Wechseln
    set currentIndex $idx
    _loadCurrentToEditor
    updatePreview
    _fireCallback onchange
    
    return $id
}

# modified - Modified-Status abfragen oder setzen
proc mdstack::modified {{value ""}} {
    variable stack
    variable currentIndex
    
    if {$currentIndex < 0} {
        return 0
    }
    
    if {$value eq ""} {
        # Abfragen
        return [dict get [lindex $stack $currentIndex] modified]
    }
    
    # Setzen
    set entry [lindex $stack $currentIndex]
    dict set entry modified $value
    lset stack $currentIndex $entry
    
    if {$value} {
        _fireCallback onmodified
    }
    
    return $value
}

# save - Save current entry (calls onsave callback)
proc mdstack::save {} {
    variable stack
    variable currentIndex
    variable callbacks
    
    if {$currentIndex < 0} {
        return 0
    }
    
    # Text aus Editor holen
    _saveCurrentToStack
    
    # Call callback (Benutzer kann currentId/currentText/currentSource verwenden)
    if {$callbacks(onsave) ne ""} {
        uplevel #0 $callbacks(onsave)
    }
    
    # Reset modified
    modified 0
    
    return 1
}

# ============================================================
# Callbacks
# ============================================================

# onchange - Callback when stack entry changes
proc mdstack::onchange {script} {
    variable callbacks
    set callbacks(onchange) $script
}

# onmodified - Callback when text is changed
proc mdstack::onmodified {script} {
    variable callbacks
    set callbacks(onmodified) $script
}

# onsave - Callback beim Speichern
proc mdstack::onsave {script} {
    variable callbacks
    set callbacks(onsave) $script
}

# ============================================================
# Convenience: Stack-Info
# ============================================================

# size - Number of entries
proc mdstack::size {} {
    variable stack
    return [llength $stack]
}

# isEmpty - Stack leer?
proc mdstack::isEmpty {} {
    variable stack
    return [expr {[llength $stack] == 0}]
}

# index - Currenter Index
proc mdstack::index {} {
    variable currentIndex
    return $currentIndex
}

# entries - All entries (without text, metadata only)
proc mdstack::entries {} {
    variable stack
    
    set result {}
    foreach entry $stack {
        lappend result [dict create \
            id       [dict get $entry id] \
            source   [dict get $entry source] \
            modified [dict get $entry modified]]
    }
    return $result
}

# ============================================================
# Internal helper functions
# ============================================================

# ID im Stack finden
proc mdstack::_findById {id} {
    variable stack
    
    set idx 0
    foreach entry $stack {
        if {[dict get $entry id] eq $id} {
            return $idx
        }
        incr idx
    }
    return -1
}

proc mdstack::hasId {id} {
    return [expr {[_findById $id] >= 0}]
}

# Currenten Editor-Text in Stack sichern
proc mdstack::_saveCurrentToStack {} {
    variable stack
    variable currentIndex
    variable editorAPI
    
    if {$currentIndex < 0} return
    if {$editorAPI(getText) eq ""} return
    
    catch {
        set text [editorGetText]
        set entry [lindex $stack $currentIndex]
        dict set entry text $text
        lset stack $currentIndex $entry
    }
}

# Load stack entry into editor
proc mdstack::_loadCurrentToEditor {} {
    variable stack
    variable currentIndex
    variable editorAPI
    
    if {$currentIndex < 0} return
    if {$editorAPI(setText) eq ""} return
    
    set entry [lindex $stack $currentIndex]
    set text [dict get $entry text]
    catch {editorSetText $text}
}

# Editor leeren
proc mdstack::_clearEditor {} {
    variable editorAPI
    
    if {$editorAPI(clear) eq ""} return
    catch {editorClear}
}

# Trigger callback
proc mdstack::_fireCallback {name} {
    variable callbacks
    
    if {$callbacks($name) ne ""} {
        catch {uplevel #0 $callbacks($name)}
    }
}

# ============================================================
# Compatibility (legacy wrapper)
# ============================================================

# getText - Alias for editorGetText (backward compatibility)
proc mdstack::getText {} {
    return [currentText]
}

# setText - Alias for editorSetText + stack update
proc mdstack::setText {text} {
    variable stack
    variable currentIndex
    
    catch {editorSetText $text}
    
    # Also update in stack
    if {$currentIndex >= 0} {
        set entry [lindex $stack $currentIndex]
        dict set entry text $text
        lset stack $currentIndex $entry
    }
}

# attachEditor - Legacy wrapper for setEditorAPI
# For mdtext-compatible widgets
proc mdstack::attachEditor {w args} {
    array set opts [list \
        -gettext  [list $w get] \
        -settext  [list $w set] \
        -onchange [list $w onchange]]
    array set opts $args
    
    # Auf neue API mappen
    setEditorAPI \
        -getText    $opts(-gettext) \
        -setText    $opts(-settext) \
        -clear      [list $w clear]
    
    # Change-Callback einrichten
    if {$opts(-onchange) ne ""} {
        catch {
            uplevel #0 [list {*}$opts(-onchange) [list mdstack::_onEditorChange]]
        }
    }
}

# attachPreview - Legacy wrapper for setPreviewAPI
proc mdstack::attachPreview {w args} {
    array set opts {
        -render ""
    }
    array set opts $args
    
    if {$opts(-render) eq ""} {
        set opts(-render) [list mdstack::_defaultRender $w]
    }
    
    setPreviewAPI -render $opts(-render)
    updatePreview
}

# detachEditor - Reset editor API
proc mdstack::detachEditor {} {
    variable editorAPI
    
    _saveCurrentToStack
    
    array set editorAPI {
        getText    ""
        setText    ""
        clear      ""
        isModified ""
    }
}

# Interner Change-Handler
proc mdstack::_onEditorChange {} {
    variable currentIndex
    
    if {$currentIndex >= 0} {
        modified 1
        updatePreview
    }
}

# Default-Render (verwendet mdparser + mdmodel + mdviewer)
# Diese Proc ruft mdparser/mdmodel/mdviewer direkt auf — das ist bewusst.
# Fuer eigene Renderer: -render Callback bei setPreviewAPI uebergeben.
proc mdstack::_defaultRender {w text} {
    if {![winfo exists $w]} return
    
    catch {
        set ast [mdparser::parse $text]
        set doc [mdmodel::new $ast]
        mdviewer::renderModel $w $doc
    }
}
