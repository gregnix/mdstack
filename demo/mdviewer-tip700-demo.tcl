#!/usr/bin/env wish
# ============================================================
# mdviewer-tip700-demo.tcl -- TIP-700-Rendering-Demo
# ============================================================
# Demonstrates the integration of TIP-700-Markdown features
# in mdviewer:
#   - YAML Frontmatter -> Meta-Panel
#   - Bracketed Spans   -> Semantic colors
#   - Fenced Divs       -> Background marking
#   - Shortcut Refs     -> Navigable links
#
# Usage:
#   wish mdviewer-tip700-demo.tcl [file.md]
#
# Without argument, demo-tip700.md is loaded.

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require Tk
package require mdparser 0.2
package require mdmodel 0.1
package require mdviewer 0.3
package require mdvalidator 0.1

# ============================================================
# Global Variables
# ============================================================

set ::currentFile ""
set ::statusText  "Ready"
set ::fontSize    11

# ============================================================
# Farb-Schema (TIP-700-Klassen)
# ============================================================

# Span-Klassen: Tcl Command Syntax
array set ::spanColors {
    cmd     {fg #1a5276 bold 1 italic 0}
    sub     {fg #1a5276 bold 1 italic 0}
    lit     {fg #1a5276 bold 1 italic 0}
    optlit  {fg #5b7fa5 bold 1 italic 0}
    arg     {fg #196f3d bold 0 italic 1}
    optarg  {fg #4a8c6a bold 0 italic 1}
    optdot  {fg #4a8c6a bold 0 italic 1}
    ins     {fg #6c3483 bold 0 italic 1}
    ccmd    {fg #7b241c bold 1 italic 0}
    cargs   {fg #a04000 bold 0 italic 1}
    ret     {fg #a04000 bold 0 italic 0}
}

# Div-Klassen: Hintergrundfarben
array set ::divColors {
    synopsis   #e8f0fe
    example    #f0f8f0
    arguments  #fef9e7
    note       #fef3e2
    warning    #fdedec
}

# ============================================================
# GUI
# ============================================================

wm title . "TIP 700 Viewer"
wm geometry . 1000x750
wm minsize . 700 500

# --- Farb-Schema ---
set bg "#fafafa"
set fg "#1a1a1a"

ttk::style configure TFrame -background $bg
ttk::style configure TLabel -background $bg -foreground $fg
ttk::style configure TButton -padding {8 4}

# --- Meta-Panel (YAML Frontmatter) ---

ttk::frame .meta -relief flat -padding {10 6}
pack .meta -side top -fill x

ttk::label .meta.icon -text "YAML" -font {{} 9 bold} \
    -foreground white -background #2e86c1 -padding {6 2} -anchor center
pack .meta.icon -side left -padx {0 8}

ttk::label .meta.info -text "" -font {{} 10} -wraplength 800
pack .meta.info -side left -fill x -expand 1

ttk::separator .metasep -orient horizontal
pack .metasep -side top -fill x

# --- Toolbar ---

ttk::frame .toolbar -padding {8 4}
pack .toolbar -side top -fill x

ttk::button .toolbar.open -text "Open..." -command cmd::openFile
pack .toolbar.open -side left -padx {0 6}

ttk::button .toolbar.reload -text "Reload" -command cmd::reloadFile
pack .toolbar.reload -side left -padx {0 6}

ttk::separator .toolbar.sep1 -orient vertical
pack .toolbar.sep1 -side left -fill y -padx 6

ttk::label .toolbar.fontlbl -text "Font:"
pack .toolbar.fontlbl -side left -padx {0 4}

spinbox .toolbar.fontsize -from 8 -to 20 -width 3 \
    -textvariable ::fontSize -command cmd::applyFontSize
pack .toolbar.fontsize -side left -padx {0 6}

ttk::separator .toolbar.sep2 -orient vertical
pack .toolbar.sep2 -side left -fill y -padx 6

ttk::button .toolbar.validate -text "Validieren" -command cmd::validateAst
pack .toolbar.validate -side left -padx {0 6}

ttk::button .toolbar.legend -text "Legende" -command cmd::showLegend
pack .toolbar.legend -side left -padx {0 6}

ttk::label .toolbar.status -textvariable ::statusText \
    -foreground #666666 -font {{} 9}
pack .toolbar.status -side right

ttk::separator .toolsep -orient horizontal
pack .toolsep -side top -fill x

# --- Main area: TOC + Viewer ---

ttk::panedwindow .pw -orient horizontal
pack .pw -side top -fill both -expand 1

# TOC-Panel
ttk::frame .pw.toc
.pw add .pw.toc -weight 0

ttk::label .pw.toc.title -text "Contents" -font {{} 10 bold} \
    -padding {8 4}
pack .pw.toc.title -side top -fill x

listbox .pw.toc.list -width 28 -font {{} 10} \
    -selectmode browse -activestyle none \
    -borderwidth 0 -highlightthickness 0 \
    -background #f5f5f5
pack .pw.toc.list -side top -fill both -expand 1
bind .pw.toc.list <<ListboxSelect>> cmd::tocSelect

# Viewer-Panel
ttk::frame .pw.viewer
.pw add .pw.viewer -weight 1

mdviewer::create .pw.viewer.v -fontsize $::fontSize -tablemode frame
pack .pw.viewer.v -fill both -expand 1

# ============================================================
# Kommandos
# ============================================================

namespace eval cmd {}

proc cmd::openFile {} {
    set f [tk_getOpenFile -filetypes {
        {{Markdown} {.md}}
        {{All Files} {*}}
    }]
    if {$f ne ""} { cmd::loadFile $f }
}

proc cmd::reloadFile {} {
    if {$::currentFile ne ""} {
        cmd::loadFile $::currentFile
    }
}

proc cmd::loadFile {file} {
    set ::currentFile $file
    set ::statusText "Loading [file tail $file]..."
    update

    if {[catch {
        set fd [open $file r]
        fconfigure $fd -encoding utf-8
        set content [read $fd]
        close $fd
    } err]} {
        tk_messageBox -icon error -message "Read error:\n$err"
        set ::statusText "Error"
        return
    }

    if {[catch {
        set ::ast [mdparser::parse $content]
        set ::doc [mdmodel::new $::ast]
    } err]} {
        tk_messageBox -icon error -message "Parse error:\n$err"
        set ::statusText "Parse error"
        return
    }

    # Update Meta-Panel
    cmd::updateMeta

    # Render
    mdviewer::configure .pw.viewer.v -root [file dirname $file]
    mdviewer::configure .pw.viewer.v -fontsize $::fontSize
    mdviewer::renderModel .pw.viewer.v $::doc

    # Apply TIP-700-Styling
    cmd::applyTip700Styling

    # Update TOC
    cmd::updateTOC

    # Statistics
    set nBlocks [llength [dict get $::ast blocks]]
    set nRefs [dict size [dict get $::ast reflinks]]
    set errs [mdvalidator::validate $::ast]
    set valid [expr {[llength $errs] == 0 ? "valid" : "[llength $errs] errors"}]

    set ::statusText "[file tail $file] | $nBlocks blocks | $nRefs refs | $valid"
    wm title . "TIP 700 Viewer - [file tail $file]"
}

proc cmd::updateMeta {} {
    set meta [dict get $::ast meta]
    if {[dict size $meta] == 0} {
        .meta.info configure -text "(no YAML Frontmatter)"
        return
    }
    set parts {}
    dict for {k v} $meta {
        lappend parts "$k: $v"
    }
    .meta.info configure -text [join $parts "  |  "]
}

proc cmd::applyTip700Styling {} {
    set t [mdviewer::widget .pw.viewer.v]
    set baseSize $::fontSize

    # Configure Span classes
    foreach {cls spec} [array get ::spanColors] {
        set tag "span_${cls}"
        set fg   [dict get $spec fg]
        set bold [dict get $spec bold]
        set ital [dict get $spec italic]

        # Determine font style
        set style ""
        if {$bold && $ital} {
            set style "bold italic"
        } elseif {$bold} {
            set style "bold"
        } elseif {$ital} {
            set style "italic"
        }

        if {$style ne ""} {
            $t tag configure $tag -foreground $fg \
                -font [list {} $baseSize $style]
        } else {
            $t tag configure $tag -foreground $fg
        }

        # Span-Tags must be above strong/em
        $t tag raise $tag
    }

    # Configure Div classes
    foreach {cls bg} [array get ::divColors] {
        set tag "div_${cls}"
        $t tag configure $tag -background $bg \
            -lmargin1 12 -lmargin2 12 -rmargin 12 \
            -spacing1 4 -spacing3 4
    }
}

proc cmd::updateTOC {} {
    .pw.toc.list delete 0 end
    set ::tocAnchors {}
    if {![info exists ::doc] || $::doc eq ""} return

    foreach h [mdmodel::headings $::doc] {
        set level [dict get $h level]
        set text [dict get $h text]
        set anchor [dict get $h anchor]

        set indent [string repeat "  " [expr {$level - 1}]]
        .pw.toc.list insert end "${indent}${text}"
        lappend ::tocAnchors $anchor
    }
}

proc cmd::tocSelect {} {
    set sel [.pw.toc.list curselection]
    if {$sel eq ""} return
    set anchor [lindex $::tocAnchors $sel]
    mdviewer::gotoAnchor .pw.viewer.v $anchor
}

proc cmd::applyFontSize {} {
    if {$::currentFile ne ""} {
        mdviewer::configure .pw.viewer.v -fontsize $::fontSize
        mdviewer::renderModel .pw.viewer.v $::doc
        cmd::applyTip700Styling
    }
}

proc cmd::validateAst {} {
    if {![info exists ::ast]} {
        tk_messageBox -icon info -message "No document loaded."
        return
    }
    set normal [mdvalidator::report $::ast]
    set strict [mdvalidator::report $::ast -strict]
    tk_messageBox -icon info -title "AST Validation" \
        -message "Normal:\n$normal\n\nStrict:\n$strict"
}

proc cmd::showLegend {} {
    if {[winfo exists .legend]} {
        raise .legend
        return
    }
    toplevel .legend
    wm title .legend "TIP 700 Classes Legend"
    wm geometry .legend 380x450

    text .legend.t -font {{} 11} -wrap word -padx 12 -pady 8 \
        -background white -borderwidth 0 -highlightthickness 0
    pack .legend.t -fill both -expand 1

    set t .legend.t
    set sz 11

    $t insert end "TIP 700 Span Classes\n" {title}
    $t insert end "\n"
    $t tag configure title -font [list {} 13 bold] -spacing3 4

    # Display Span classes
    set items {
        cmd     "Command Name"          "array, puts, set"
        sub     "Subcommand"            "get, set, names"
        lit     "Literal (required)"      "-code, -level"
        optlit  "Literal (optional)"     "-nonewline"
        arg     "Argument (required)"     "string, arrayName"
        optarg  "Argument (optional)"    "channelId, pattern"
        optdot  "Argument (variable)"    "arg ..."
        ins     "Instance Command"       "pathName"
        ccmd    "C-API Function"         "Tcl_WriteObj"
        cargs   "C-API Arguments"        "interp, objPtr"
        ret     "C API return value"    "int, char *"
    }

    foreach {cls desc example} $items {
        set fg [dict get $::spanColors($cls) fg]
        set bold [dict get $::spanColors($cls) bold]
        set ital [dict get $::spanColors($cls) italic]

        set style ""
        if {$bold && $ital} { set style "bold italic"
        } elseif {$bold} { set style "bold"
        } elseif {$ital} { set style "italic" }

        set tag "leg_${cls}"
        if {$style ne ""} {
            $t tag configure $tag -foreground $fg -font [list {} $sz $style]
        } else {
            $t tag configure $tag -foreground $fg
        }

        $t insert end ".$cls" [list $tag]
        $t insert end "  $desc  " {}
        $t insert end "($example)" [list grey]
        $t insert end "\n"
    }

    $t tag configure grey -foreground #888888

    $t insert end "\nDiv Classes\n" {title}
    $t insert end "\n"

    foreach {cls bg} [array get ::divColors] {
        set dtag "dleg_${cls}"
        $t tag configure $dtag -background $bg -lmargin1 8 -rmargin 8
        $t insert end "  ::: .$cls  \n" [list $dtag]
    }

    $t configure -state disabled
}

# ============================================================
# Keyboard Bindings
# ============================================================

bind . <Control-o> cmd::openFile
bind . <Control-r> cmd::reloadFile
bind . <Control-q> exit
bind . <Control-plus>  {incr ::fontSize 1; cmd::applyFontSize}
bind . <Control-minus> {incr ::fontSize -1; cmd::applyFontSize}
bind . <Control-0>     {set ::fontSize 11; cmd::applyFontSize}

# ============================================================
# Start
# ============================================================

# Load file: argument or demo-tip700.md
set startFile ""
if {$argc > 0} {
    set startFile [lindex $argv 0]
} else {
    set demoFile [file join [file dirname [info script]] demo-tip700.md]
    if {[file exists $demoFile]} {
        set startFile $demoFile
    }
}

if {$startFile ne "" && [file exists $startFile]} {
    after idle [list cmd::loadFile $startFile]
} else {
    set ::statusText "No file loaded. Ctrl+O to open."
}
