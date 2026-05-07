#!/usr/bin/env wish
# mdviewer-docir-demo.tcl -- minimal Markdown viewer using DocIR pipeline
#
# Pipeline:
#   mdparser  (mdstack)     Markdown → mdparser-AST
#   docir-md  (mdstack)     mdparser-AST → DocIR
#   docir     (man-viewer)  DocIR validator
#   docir-renderer-tk       DocIR → Tk text widget
#
# This file is identical in both repos:
#   man-viewer/app/mdviewer-docir-demo.tcl
#   mdstack/demo/mdviewer-docir-demo.tcl
#
# Setup requirement:
#   Both man-viewer and mdstack must be reachable via auto_path
#   BEFORE this script runs. Typical ~/.tclshrc:
#
#     lappend auto_path /path/to/man-viewer
#     lappend auto_path /path/to/mdstack
#
#   The script does NOT search for either repo — if package require
#   fails you get a clear error window with diagnostics.
#
# Usage:
#   wish mdviewer-docir-demo.tcl                       # show file dialog
#   wish mdviewer-docir-demo.tcl path/to/file.md       # open that file

# Eigene Module aus dem Repo (Tests laufen aus dem Repo)
if {![info exists ::_setup_done]} {
    lappend ::auto_path [file normalize [file join [file dirname [info script]] .. lib]]
    set ::_setup_done 1
}


package require Tcl 8.6-
package require Tk

# Modul-Pfade konfigurieren
# ============================================================
# Load all modules via package require
# ============================================================

set loadErrors {}
foreach pkg {mdstack::parser docir docir::mdSource docir::rendererTk} {
    if {[catch {package require $pkg} err]} {
        lappend loadErrors "package require $pkg: $err"
    }
}

# ============================================================
# Copyable error window
# ============================================================

proc showSetupError {messages} {
    toplevel .setupErr
    wm title .setupErr "mdviewer-docir-demo: setup error"
    wm geometry .setupErr 720x520

    ttk::label .setupErr.head -text "Cannot start mdviewer-docir-demo:" \
        -foreground "#a00" -font {-size 12 -weight bold}
    pack .setupErr.head -side top -anchor w -padx 10 -pady {10 4}

    ttk::frame .setupErr.body
    text .setupErr.body.t -wrap word -height 22 \
        -yscrollcommand {.setupErr.body.sb set}
    ttk::scrollbar .setupErr.body.sb -command {.setupErr.body.t yview}
    grid .setupErr.body.t  -row 0 -column 0 -sticky nsew
    grid .setupErr.body.sb -row 0 -column 1 -sticky ns
    grid columnconfigure .setupErr.body 0 -weight 1
    grid rowconfigure    .setupErr.body 0 -weight 1
    pack .setupErr.body -side top -fill both -expand 1 -padx 10 -pady 4

    foreach m $messages {
        .setupErr.body.t insert end "$m\n"
    }
    .setupErr.body.t insert end "\n"
    .setupErr.body.t insert end "Hint: add both man-viewer and mdstack to auto_path before running.\n"
    .setupErr.body.t insert end "Example:\n"
    .setupErr.body.t insert end "  lappend auto_path /path/to/man-viewer\n"
    .setupErr.body.t insert end "  lappend auto_path /path/to/mdstack\n"
    .setupErr.body.t insert end "\n--- Diagnostic info ---\n\n"
    .setupErr.body.t insert end "auto_path:\n"
    foreach p $::auto_path {
        .setupErr.body.t insert end "  $p\n"
    }
    .setupErr.body.t insert end "\ntcl::tm::path:\n"
    foreach p [::tcl::tm::path list] {
        .setupErr.body.t insert end "  $p\n"
    }
    .setupErr.body.t insert end "\nscript:      [info script]\n"
    .setupErr.body.t insert end "tcl_version: [info patchlevel]\n"

    .setupErr.body.t configure -state disabled

    ttk::frame .setupErr.btns
    ttk::button .setupErr.btns.copy -text "Copy all" -command {
        clipboard clear
        clipboard append [.setupErr.body.t get 1.0 end-1c]
        .setupErr.btns.copy configure -text "Copied!"
        after 1200 {.setupErr.btns.copy configure -text "Copy all"}
    }
    ttk::button .setupErr.btns.close -text "Close" -command {exit 1}
    pack .setupErr.btns.close -side right -padx 10 -pady 8
    pack .setupErr.btns.copy  -side right -padx {10 0} -pady 8
    pack .setupErr.btns -side bottom -fill x

    wm withdraw .
    tkwait window .setupErr
    exit 1
}

if {[llength $loadErrors] > 0} {
    showSetupError $loadErrors
}

# ============================================================
# UI
# ============================================================

namespace eval ::mvd {
    variable currentFile ""
    variable darkMode    0
    variable fontSize    11
}

wm title . "mdviewer-docir-demo (DocIR pipeline)"
wm geometry . 800x600

ttk::frame .tb
ttk::button .tb.open  -text "Open..."     -command openDialog
ttk::button .tb.theme -text "Toggle dark" -command toggleDark
ttk::label  .tb.info  -text "" -anchor w
pack .tb.open  -side left -padx {4 2} -pady 4
pack .tb.theme -side left -padx 2     -pady 4
pack .tb.info  -side left -padx 8     -pady 4 -fill x -expand 1
pack .tb -side top -fill x

ttk::frame .body
text .body.t -wrap word -insertwidth 0 -exportselection 1 \
    -yscrollcommand {.body.sb set}
ttk::scrollbar .body.sb -command {.body.t yview}
grid .body.t  -row 0 -column 0 -sticky nsew
grid .body.sb -row 0 -column 1 -sticky ns
grid columnconfigure .body 0 -weight 1
grid rowconfigure    .body 0 -weight 1
pack .body -side top -fill both -expand 1

ttk::frame .diag
text .diag.t -height 6 -wrap word -foreground "#a00" \
    -yscrollcommand {.diag.sb set}
ttk::scrollbar .diag.sb -command {.diag.t yview}
grid .diag.t  -row 0 -column 0 -sticky nsew
grid .diag.sb -row 0 -column 1 -sticky ns
grid columnconfigure .diag 0 -weight 1
grid rowconfigure    .diag 0 -weight 1

ttk::label .status -text "ready" -relief sunken -anchor w
pack .status -side bottom -fill x

# ============================================================
# Actions
# ============================================================

proc openDialog {} {
    set f [tk_getOpenFile -title "Open Markdown file" \
        -filetypes {{Markdown {.md .markdown}} {All *}}]
    if {$f ne ""} { loadFile $f }
}

proc loadFile {path} {
    if {![file exists $path]} {
        showDiagnostics [list "File not found: $path"]
        return
    }
    set ::mvd::currentFile $path
    set fh [open $path r]
    fconfigure $fh -encoding utf-8
    set md [read $fh]
    close $fh

    .tb.info configure -text "[file tail $path]"
    wm title . "mdviewer-docir-demo — [file tail $path]"

    if {[catch {renderMarkdown $md} err]} {
        showDiagnostics [list "Render-Fehler: $err" "" \
                              "Stack-Trace:" $::errorInfo]
    }
}

proc renderMarkdown {md} {
    set ast [mdstack::parser::parse $md]
    set ir  [docir::md::fromAst $ast]

    set errs [docir::validate $ir]
    if {[llength $errs] > 0} {
        showDiagnostics $errs
    } else {
        hideDiagnostics
    }
    docir::renderer::tk::render .body.t $ir [renderOptions]
}

proc showDiagnostics {messages} {
    .diag.t configure -state normal
    .diag.t delete 1.0 end
    .diag.t insert end "DocIR-Validator hat Probleme gefunden:\n\n"
    foreach m $messages {
        .diag.t insert end "  • $m\n"
    }
    .diag.t configure -state disabled
    if {![winfo ismapped .diag]} {
        pack .diag -side bottom -fill x -before .status
    }
}

proc hideDiagnostics {} {
    if {[winfo ismapped .diag]} {
        pack forget .diag
    }
}

proc renderOptions {} {
    set colors {}
    if {$::mvd::darkMode} {
        set colors [dict create \
            background "#1e1e1e" \
            foreground "#d4d4d4" \
            heading    "#9cdcfe" \
            link       "#569cd6" \
            preBg      "#252526"]
    }
    return [dict create \
        fontSize   $::mvd::fontSize \
        fontFamily "TkDefaultFont" \
        monoFamily "TkFixedFont" \
        darkMode   $::mvd::darkMode \
        colors     $colors]
}

proc toggleDark {} {
    set ::mvd::darkMode [expr {!$::mvd::darkMode}]
    if {$::mvd::currentFile ne ""} {
        set fh [open $::mvd::currentFile r]
        fconfigure $fh -encoding utf-8
        set md [read $fh]
        close $fh
        catch {renderMarkdown $md}
    }
    if {$::mvd::darkMode} {
        .body.t configure -background "#1e1e1e" -foreground "#d4d4d4"
    } else {
        .body.t configure -background white -foreground black
    }
}

# ============================================================
# Startup
# ============================================================

if {[llength $argv] > 0} {
    loadFile [lindex $argv 0]
} else {
    .body.t configure -state normal
    .body.t insert end "mdviewer-docir-demo\n\n"
    .body.t insert end "Pipeline:\n  mdparser (mdstack)\n    -> docir-md (mdstack)\n    -> docir-renderer-tk (man-viewer)\n\n"
    .body.t insert end "Use File -> Open or pass a .md path on the command line.\n"
    .body.t configure -state disabled
}
