# mdoutline-0.1.tm
#
# Heading-Outline-Panel for den mdtext-Editor.
# Zeigt Headings als Baumstruktur, Klick springt zur Stelle im Editor.
#
# Abhaengigkeiten: Tk, mdtext 0.1
#
# API:
#   mdstack::outline::create $path -editor $ed  -> $path
#   mdstack::outline::refresh $path
#   mdstack::outline::gotoSelection $path
#   mdstack::outline::dispatch $path subcommand
#   mdstack::outline::destroy $path

package require Tk
package require mdstack::text 0.1

package provide mdstack::outline 0.1

namespace eval mdstack::outline {
    namespace export create refresh gotoSelection dispatch destroy
    variable state
    array set state {}
}

proc mdstack::outline::create {path args} {
    variable state

    # Parse options
    set editor ""
    set refreshMs 500
    foreach {k v} $args {
        switch -- $k {
            -editor   { set editor $v }
            -refresh  { set refreshMs $v }
            default   { error "mdstack::outline::create: unknown option $k" }
        }
    }
    if {$editor eq ""} {
        error "mdstack::outline::create: -editor is required"
    }

    ttk::frame $path

    # Treeview for Headings
    set tree [ttk::treeview $path.tree \
        -columns {idx level} \
        -displaycolumns {} \
        -show tree \
        -selectmode browse \
        -height 12]

    ttk::scrollbar $path.sb -orient vertical -command [list $tree yview]
    $tree configure -yscrollcommand [list $path.sb set]

    pack $path.sb -side right -fill y
    pack $tree -side left -fill both -expand 1

    # Tag-Styling for verschiedene Levels
    $tree tag configure h1 -font [list {} 11 bold]
    $tree tag configure h2 -font [list {} 10 bold]
    $tree tag configure h3 -font [list {} 10 {}]
    $tree tag configure h4 -font [list {} 9 italic]
    $tree tag configure h5 -font [list {} 9 {}]
    $tree tag configure h6 -font [list {} 8 {}]

    # State
    set state($path,tree) $tree
    set state($path,editor) $editor
    set state($path,refreshMs) $refreshMs
    set state($path,afterid) ""

    # Doppelklick oder Select springt zum Heading
    bind $tree <<TreeviewSelect>> [list mdstack::outline::gotoSelection $path]

    # Initiales Refresh
    mdstack::outline::refresh $path

    return $path
}

proc mdstack::outline::refresh {path} {
    variable state
    set tree $state($path,tree)
    set ed $state($path,editor)

    # Alle Items loeschen
    $tree delete [$tree children {}]

    # Headings aus dem Editor holen
    set headings [mdstack::text::getHeadings $ed]

    foreach h $headings {
        lassign $h level text idx

        # Indentation via text prefix
        set indent [string repeat "  " [expr {$level - 1}]]
        set display "${indent}${text}"

        $tree insert {} end \
            -text $display \
            -values [list $idx $level] \
            -tags [list "h${level}"]
    }
}

proc mdstack::outline::gotoSelection {path} {
    variable state
    set tree $state($path,tree)
    set ed $state($path,editor)

    set sel [$tree selection]
    if {$sel eq ""} return

    set values [$tree item $sel -values]
    if {[llength $values] == 0} return

    set idx [lindex $values 0]
    set t [mdstack::text::_t $ed]

    # Cursor setzen und sichtbar machen
    $t mark set insert $idx
    $t see $idx

    # Highlight line (briefly)
    set lineEnd [$t index "$idx lineend"]
    $t tag remove outline_highlight 1.0 end
    $t tag add outline_highlight $idx $lineEnd
    $t tag configure outline_highlight -background "#fff3cd"
    after 1500 [list catch [list $t tag remove outline_highlight 1.0 end]]
}

# Dispatcher for mdcontextmenu-Kompatibilitaet
proc mdstack::outline::dispatch {path subcmd args} {
    variable state
    switch -- $subcmd {
        tree    { return $state($path,tree) }
        editor  { return $state($path,editor) }
        refresh { return [mdstack::outline::refresh $path] }
        goto    { return [mdstack::outline::gotoSelection $path] }
        default { error "mdstack::outline::dispatch: unknown subcommand $subcmd" }
    }
}

proc mdstack::outline::destroy {path} {
    variable state
    if {[info exists state($path,afterid)] && $state($path,afterid) ne ""} {
        after cancel $state($path,afterid)
    }
    catch {unset state($path,tree)}
    catch {unset state($path,editor)}
    catch {unset state($path,refreshMs)}
    catch {unset state($path,afterid)}
    catch {::destroy $path}
}
