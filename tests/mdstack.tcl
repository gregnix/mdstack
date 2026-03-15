# mdstack.tcl - Tests for mdstack Orchestrator
# Run: tclsh test/mdstack.tcl

set scriptDir [file dirname [info script]]
tcl::tm::path add [file normalize [file join $scriptDir .. lib]]

package require tcltest
namespace import ::tcltest::*

package require mdstack 0.1

# ============================================================
# Stack-Grundfunktionen
# ============================================================

test stack-1 "push und currentId" -body {
    mdstack::clear
    mdstack::push -id "test1" -text "# Test" -source "unit"
    mdstack::currentId
} -result "test1"

test stack-2 "push mehrere" -body {
    mdstack::clear
    mdstack::push -id "a" -text "A" -source "unit"
    mdstack::push -id "b" -text "B" -source "unit"
    mdstack::push -id "c" -text "C" -source "unit"
    mdstack::size
} -result 3

test stack-3 "history" -body {
    mdstack::clear
    mdstack::push -id "x" -text "" -source ""
    mdstack::push -id "y" -text "" -source ""
    mdstack::history
} -result {x y}

test stack-4 "pop" -body {
    mdstack::clear
    mdstack::push -id "first" -text "" -source ""
    mdstack::push -id "second" -text "" -source ""
    mdstack::pop
    mdstack::currentId
} -result "first"

test stack-5 "pop letzten" -body {
    mdstack::clear
    mdstack::push -id "only" -text "" -source ""
    mdstack::pop
    mdstack::isEmpty
} -result 1

test stack-6 "goto" -body {
    mdstack::clear
    mdstack::push -id "one" -text "1" -source ""
    mdstack::push -id "two" -text "2" -source ""
    mdstack::push -id "three" -text "3" -source ""
    mdstack::goto "one"
    mdstack::currentId
} -result "one"

test stack-7 "clear" -body {
    mdstack::clear
    mdstack::push -id "a" -text "" -source ""
    mdstack::push -id "b" -text "" -source ""
    mdstack::clear
    list [mdstack::size] [mdstack::isEmpty]
} -result {0 1}

# ============================================================
# Text-Verwaltung
# ============================================================

test text-1 "currentText" -body {
    mdstack::clear
    mdstack::push -id "doc" -text "# Hello" -source ""
    mdstack::currentText
} -result "# Hello"

test text-2 "setText ohne Editor" -body {
    mdstack::clear
    mdstack::push -id "doc" -text "old" -source ""
    mdstack::setText "new"
    mdstack::currentText
} -result "new"

test text-3 "currentSource" -body {
    mdstack::clear
    mdstack::push -id "note" -text "" -source "noteskit"
    mdstack::currentSource
} -result "noteskit"

# ============================================================
# Modified-Status
# ============================================================

test modified-1 "initial nicht modified" -body {
    mdstack::clear
    mdstack::push -id "doc" -text "" -source ""
    mdstack::modified
} -result 0

test modified-2 "modified setzen" -body {
    mdstack::clear
    mdstack::push -id "doc" -text "" -source ""
    mdstack::modified 1
    mdstack::modified
} -result 1

test modified-3 "modified reset" -body {
    mdstack::clear
    mdstack::push -id "doc" -text "" -source ""
    mdstack::modified 1
    mdstack::modified 0
    mdstack::modified
} -result 0

# ============================================================
# current Dict
# ============================================================

test current-1 "current als Dict" -body {
    mdstack::clear
    mdstack::push -id "myid" -text "mytext" -source "mysource"
    set entry [mdstack::current]
    list [dict get $entry id] [dict get $entry source]
} -result {myid mysource}

test current-2 "current bei leerem Stack" -body {
    mdstack::clear
    mdstack::current
} -result {}

# ============================================================
# entries
# ============================================================

test entries-1 "entries ohne Text" -body {
    mdstack::clear
    mdstack::push -id "a" -text "long text here" -source "src"
    set entries [mdstack::entries]
    set first [lindex $entries 0]
    list [dict exists $first text] [dict get $first id]
} -result {0 a}

# ============================================================
# Callbacks
# ============================================================

test callback-1 "onchange wird aufgerufen" -body {
    mdstack::clear
    set ::callbackCalled 0
    mdstack::onchange { set ::callbackCalled 1 }
    mdstack::push -id "test" -text "" -source ""
    set ::callbackCalled
} -result 1

test callback-2 "onmodified wird aufgerufen" -body {
    mdstack::clear
    set ::modifiedCalled 0
    mdstack::onmodified { set ::modifiedCalled 1 }
    mdstack::push -id "test" -text "" -source ""
    mdstack::modified 1
    set ::modifiedCalled
} -result 1

test callback-3 "onsave wird aufgerufen" -body {
    mdstack::clear
    set ::saveCalled 0
    mdstack::onsave {
        set ::saveCalled 1
    }
    mdstack::push -id "doc1" -text "content" -source "myapp"
    mdstack::save
    set ::saveCalled
} -result 1

# ============================================================
# Editor-API
# ============================================================

test editorapi-1 "setEditorAPI Pflichtfelder" -body {
    mdstack::clear
    mdstack::detachEditor
    catch {mdstack::setEditorAPI -getText {return "x"}} err
    string match "*-setText*" $err
} -result 1

test editorapi-2 "setEditorAPI komplett" -body {
    mdstack::clear
    set ::testText ""
    mdstack::setEditorAPI \
        -getText    {set ::testText} \
        -setText    {set ::testText} \
        -clear      {set ::testText ""}
    set ::testText "hello"
    mdstack::editorGetText
} -result "hello"

test editorapi-3 "editorSetText" -body {
    mdstack::clear
    set ::testText ""
    mdstack::setEditorAPI \
        -getText    {set ::testText} \
        -setText    {set ::testText} \
        -clear      {set ::testText ""}
    mdstack::editorSetText "world"
    set ::testText
} -result "world"

test editorapi-4 "editorClear" -body {
    mdstack::clear
    set ::testText "something"
    mdstack::setEditorAPI \
        -getText    {set ::testText} \
        -setText    {set ::testText} \
        -clear      {set ::testText ""}
    mdstack::editorClear
    set ::testText
} -result ""

test editorapi-5 "editorIsModified default" -body {
    mdstack::clear
    mdstack::detachEditor
    mdstack::editorIsModified
} -result 0

# ============================================================
# Duplikate
# ============================================================

test duplicate-1 "push gleiche ID wechselt nur" -body {
    mdstack::clear
    mdstack::push -id "same" -text "first" -source ""
    mdstack::push -id "other" -text "other" -source ""
    mdstack::push -id "same" -text "ignored" -source ""
    list [mdstack::size] [mdstack::currentId]
} -result {2 same}

# ============================================================
# Cleanup
# ============================================================

mdstack::clear
mdstack::detachEditor
mdstack::onchange {}
mdstack::onmodified {}
mdstack::onsave {}

cleanupTests
