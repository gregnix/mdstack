#!/usr/bin/env wish
# ============================================================
# Markdown Viewer App v2 – Showcase app for mdstack 2.0
# ============================================================
# All features integrated:
#   - TOC-Navigation mit Anchor-Links
#   - Volltextsuche (mdsearch) mit Highlight + Navigation
#   - Fontsize-Steuerung (Spinbox)
#   - PDF-Export (optional, wenn pdf4tcl vorhanden)
#   - Link-Handler (intern, extern, relativ)
#   - Keyboard-Shortcuts
#   - Cross-Platform (Windows & Linux)
#
# Verwendung:
#   wish mdviewer-app-v2.tcl [file.md]
#

tcl::tm::path add [file normalize [file join [file dirname [info script]] .. lib]]

package require Tk
package require mdparser 0.2
package require mdmodel 0.1
package require mdviewer 0.3
package require mdsearch 0.1

# PDF-Export optional
set ::hasPdf [expr {![catch {package require mdpdf 0.2}]}]

# ============================================================
# Globale Variablen
# ============================================================

set ::currentFile ""
set ::currentDoc  ""
set ::searchTerm  ""
set ::statusText  "Bereit"
set ::searchInfo  ""
set ::fontSize    10

# ============================================================
# GUI
# ============================================================

wm title . "Markdown Viewer"
wm geometry . 1100x750
wm minsize . 600 400

# --- Menu bar ---

menu .menubar -tearoff 0
. configure -menu .menubar

menu .menubar.file -tearoff 0
.menubar add cascade -label "File" -menu .menubar.file
.menubar.file add command -label "Open..."     -command cmd::openFile    -accelerator "Ctrl+O"
.menubar.file add command -label "Reload"    -command cmd::reloadFile  -accelerator "Ctrl+R"
.menubar.file add separator
if {$::hasPdf} {
    .menubar.file add command -label "Export PDF…" -command cmd::exportPdf -accelerator "Ctrl+P"
    .menubar.file add separator
}
.menubar.file add command -label "Quit" -command exit -accelerator "Ctrl+Q"

menu .menubar.view -tearoff 0
.menubar add cascade -label "View" -menu .menubar.view
.menubar.view add command -label "Toggle TOC"  -command cmd::toggleTOC   -accelerator "Ctrl+T"
.menubar.view add command -label "Toggle Search" -command cmd::toggleSearch -accelerator "Ctrl+F"
.menubar.view add separator
.menubar.view add command -label "Font +"   -command {cmd::changeFontSize 1}  -accelerator "Ctrl++"
.menubar.view add command -label "Font −"   -command {cmd::changeFontSize -1} -accelerator "Ctrl+-"
.menubar.view add command -label "Font normal" -command {cmd::setFontSize 10} -accelerator "Ctrl+0"

menu .menubar.help -tearoff 0
.menubar add cascade -label "Help" -menu .menubar.help
.menubar.help add command -label "About..." -command cmd::showAbout

# --- Keyboard Bindings ---

bind . <Control-o>      cmd::openFile
bind . <Control-r>      cmd::reloadFile
bind . <Control-q>      exit
bind . <Control-f>      cmd::toggleSearch
bind . <Control-t>      cmd::toggleTOC
bind . <Control-plus>   {cmd::changeFontSize 1}
bind . <Control-minus>  {cmd::changeFontSize -1}
bind . <Control-Key-0>  {cmd::setFontSize 10}
bind . <Escape>         cmd::hideSearch
if {$::hasPdf} {
    bind . <Control-p> cmd::exportPdf
}

# --- Suchleiste (oben, initial versteckt) ---

ttk::frame .searchbar
ttk::label .searchbar.lbl -text "Search:"
ttk::entry .searchbar.entry -textvariable ::searchTerm -width 30
ttk::button .searchbar.prev -text "↑" -width 3 -command cmd::searchPrev
ttk::button .searchbar.next -text "↓" -width 3 -command cmd::searchNext
ttk::button .searchbar.close -text "✕" -width 3 -command cmd::hideSearch
ttk::label .searchbar.info -textvariable ::searchInfo -width 12

pack .searchbar.lbl .searchbar.entry .searchbar.prev .searchbar.next \
    .searchbar.info .searchbar.close -side left -padx 2 -pady 3

bind .searchbar.entry <Return>          cmd::doSearch
bind .searchbar.entry <Shift-Return>    cmd::searchPrev
bind .searchbar.entry <Escape>          cmd::hideSearch

# --- Toolbar (Fontsize) ---

ttk::frame .toolbar
ttk::separator .toolbar.sep1 -orient vertical
ttk::label .toolbar.fslbl -text "Font:"
ttk::spinbox .toolbar.fsspin -from 8 -to 24 -width 4 \
    -textvariable ::fontSize -command cmd::applyFontSize
bind .toolbar.fsspin <Return> cmd::applyFontSize

pack .toolbar.sep1 -side left -fill y -padx 4 -pady 2
pack .toolbar.fslbl .toolbar.fsspin -side left -padx 2 -pady 3
pack .toolbar -side top -fill x

# --- Haupt-Layout ---

ttk::panedwindow .pw -orient horizontal
pack .pw -fill both -expand 1

# TOC (links)
ttk::frame .pw.toc -width 220
.pw add .pw.toc -weight 0

ttk::label .pw.toc.title -text "Contents" -font {TkDefaultFont 10 bold}
pack .pw.toc.title -pady 5 -padx 5 -anchor w

ttk::scrollbar .pw.toc.sb -command [list .pw.toc.list yview]
text .pw.toc.list -width 28 -wrap word -cursor hand2 \
    -yscrollcommand [list .pw.toc.sb set] -state disabled \
    -borderwidth 0 -highlightthickness 0
pack .pw.toc.list -side left -fill both -expand 1
pack .pw.toc.sb -side right -fill y

# Viewer (rechts)
ttk::frame .pw.viewer
.pw add .pw.viewer -weight 1

mdviewer::create .pw.viewer.v \
    -onlink cmd::handleLink \
    -onclick cmd::handleClick \
    -tablemode frame
pack .pw.viewer.v -fill both -expand 1

# --- Statusbar ---

ttk::frame .statusbar
pack .statusbar -fill x -side bottom

ttk::label .statusbar.file -textvariable ::statusText -relief sunken -anchor w
ttk::label .statusbar.pos -text "" -relief sunken -anchor w -width 15
pack .statusbar.file -side left -fill x -expand 1 -padx 2 -pady 1
pack .statusbar.pos -side right -padx 2 -pady 1

# ============================================================
# Namespace cmd – Alle Kommandos
# ============================================================

namespace eval cmd {}

# --- File ---

proc cmd::openFile {} {
    set types {
        {"Markdown" {.md .markdown}}
        {"Text"     {.txt}}
        {"Alle"     *}
    }
    set file [tk_getOpenFile -filetypes $types -title "Open Markdown file"]
    if {$file ne ""} {
        cmd::loadFile $file
    }
}

proc cmd::reloadFile {} {
    if {$::currentFile ne "" && [file exists $::currentFile]} {
        cmd::loadFile $::currentFile
    }
}

proc cmd::loadFile {file} {
    set ::currentFile $file
    set ::statusText "Lade [file tail $file]…"
    update

    if {[catch {
        set fd [open $file r]
        fconfigure $fd -encoding utf-8
        set content [read $fd]
        close $fd
    } err]} {
        tk_messageBox -icon error -message "Error reading file:\n$err"
        set ::statusText "Error"
        return
    }

    if {[catch {
        set ast [mdparser::parse $content]
        set ::currentDoc [mdmodel::new $ast]
    } err]} {
        tk_messageBox -icon error -message "Parse error:\n$err"
        set ::statusText "Parse error"
        return
    }

    # Configure viewer: root = file directory (for images)
    mdviewer::configure .pw.viewer.v -root [file dirname $file]
    mdviewer::renderModel .pw.viewer.v $::currentDoc
    mdsearch::clearHighlight .pw.viewer.v

    cmd::updateTOC
    set ::statusText "[file tail $file]"
    set ::searchInfo ""
    wm title . "Markdown Viewer – [file tail $file]"
}

# --- PDF ---

proc cmd::exportPdf {} {
    if {$::currentDoc eq ""} {
        tk_messageBox -icon info -message "Kein Dokument geladen."
        return
    }

    set initialFile [file rootname [file tail $::currentFile]].pdf
    set outFile [tk_getSaveFile \
        -defaultextension .pdf \
        -filetypes {{"PDF" .pdf}} \
        -initialfile $initialFile \
        -title "PDF exportieren"]

    if {$outFile eq ""} return

    set ::statusText "Exportiere PDF…"
    update

    if {[catch {
        set ast [dict get $::currentDoc ast]
        mdpdf::export $ast $outFile \
            -title [file rootname [file tail $::currentFile]] \
            -toc 1 \
            -footer "- Page %p -" \
            -root [file dirname $::currentFile]
    } err]} {
        tk_messageBox -icon error -message "PDF error:\n$err"
        set ::statusText "PDF error"
        return
    }

    set ::statusText "PDF gespeichert: [file tail $outFile]"
    tk_messageBox -icon info -message "PDF erfolgreich exportiert:\n$outFile"
}

# --- TOC ---

proc cmd::updateTOC {} {
    set w .pw.toc.list
    $w configure -state normal
    $w delete 1.0 end

    if {$::currentDoc eq ""} {
        $w configure -state disabled
        return
    }

    # Tags for TOC entries
    $w tag configure toc1 -font "TkDefaultFont 10 bold"
    $w tag configure toc2 -font "TkDefaultFont 10"
    $w tag configure toc3 -font "TkDefaultFont 9" -foreground #555555
    $w tag configure tochover -underline 1

    set headings [mdmodel::headings $::currentDoc]
    set lineNum 1
    foreach h $headings {
        set level  [dict get $h level]
        set text   [dict get $h text]
        set anchor [dict get $h anchor]

        set indent [string repeat "  " [expr {$level - 1}]]
        $w insert end "$indent$text\n"

        # Style
        set stag "toc[expr {min($level, 3)}]"
        $w tag add $stag "$lineNum.0" "$lineNum.end"

        # Klick → gotoAnchor
        set ctag "toc_click_$lineNum"
        $w tag add $ctag "$lineNum.0" "$lineNum.end"
        $w tag configure $ctag -foreground #0066cc
        $w tag bind $ctag <Button-1> [list apply {{vp anchor} {
            mdviewer::gotoAnchor $vp $anchor
        }} .pw.viewer.v $anchor]
        $w tag bind $ctag <Enter> [list $w tag add tochover "$lineNum.0" "$lineNum.end"]
        $w tag bind $ctag <Leave> [list $w tag remove tochover "$lineNum.0" "$lineNum.end"]

        incr lineNum
    }

    $w configure -state disabled
}

proc cmd::toggleTOC {} {
    if {[.pw panes] eq ".pw.toc .pw.viewer"} {
        .pw forget .pw.toc
    } else {
        .pw insert 0 .pw.toc -weight 0
    }
}

# --- Suche ---

proc cmd::toggleSearch {} {
    if {[winfo viewable .searchbar]} {
        cmd::hideSearch
    } else {
        pack .searchbar -before .toolbar -fill x
        focus .searchbar.entry
        .searchbar.entry selection range 0 end
    }
}

proc cmd::hideSearch {} {
    pack forget .searchbar
    mdsearch::clearHighlight .pw.viewer.v
    set ::searchInfo ""
    set ::searchTerm ""
}

proc cmd::doSearch {} {
    if {$::searchTerm eq ""} {
        mdsearch::clearHighlight .pw.viewer.v
        set ::searchInfo ""
        return
    }
    set matches [mdsearch::find .pw.viewer.v $::searchTerm]
    if {[llength $matches] > 0} {
        mdsearch::next .pw.viewer.v
    }
    cmd::updateSearchInfo
}

proc cmd::searchNext {} {
    if {[mdsearch::count .pw.viewer.v] == 0 && $::searchTerm ne ""} {
        cmd::doSearch
        return
    }
    mdsearch::next .pw.viewer.v
    cmd::updateSearchInfo
}

proc cmd::searchPrev {} {
    if {[mdsearch::count .pw.viewer.v] == 0 && $::searchTerm ne ""} {
        cmd::doSearch
        return
    }
    mdsearch::prev .pw.viewer.v
    cmd::updateSearchInfo
}

proc cmd::updateSearchInfo {} {
    set total [mdsearch::count .pw.viewer.v]
    set cur   [mdsearch::current .pw.viewer.v]
    if {$total > 0} {
        set ::searchInfo "$cur / $total"
    } elseif {$::searchTerm ne ""} {
        set ::searchInfo "0 matches"
    } else {
        set ::searchInfo ""
    }
}

# --- Fontsize ---

proc cmd::changeFontSize {delta} {
    set ::fontSize [expr {max(8, min(24, $::fontSize + $delta))}]
    cmd::applyFontSize
}

proc cmd::setFontSize {size} {
    set ::fontSize $size
    cmd::applyFontSize
}

proc cmd::applyFontSize {} {
    mdviewer::setFontSize .pw.viewer.v $::fontSize
}

# --- Link-Handler ---

proc cmd::handleLink {url} {
    # Anchor-Links werden schon von mdviewer::dispatchLink behandelt.
    # Hier nur externe und relative Links.
    if {[string match "http*" $url]} {
        # Externer Link
        if {$::tcl_platform(platform) eq "windows"} {
            exec cmd /c start "" $url &
        } else {
            catch {exec xdg-open $url &}
        }
    } elseif {[string match "*.md" $url] || [string match "*.markdown" $url]} {
        # Relativer Markdown-Link
        if {$::currentFile ne ""} {
            set target [file normalize [file join [file dirname $::currentFile] $url]]
            if {[file exists $target]} {
                cmd::loadFile $target
            } else {
                set ::statusText "Not found: $url"
            }
        }
    }
}

proc cmd::handleClick {x y index tags lineText} {
    set line [lindex [split $index .] 0]
    .statusbar.pos configure -text "Z $line"
}

# --- About ---

proc cmd::showAbout {} {
    set modules "mdparser 0.2, mdmodel 0.1\nmdviewer 0.3, mdsearch 0.1"
    if {$::hasPdf} {
        append modules "\nmdpdf 0.2 (PDF-Export, pdf4tcllib)"
    }
    tk_messageBox -icon info -title "About Markdown Viewer" \
        -message "Markdown Viewer v2\n\nmdstack 2.0 Showcase app\n\nModule:\n$modules\n\nShortcuts:\nCtrl+O  Open\nCtrl+F  Search\nCtrl+T  TOC\nCtrl+P  PDF\nCtrl+/-/0  Font size"
}

# ============================================================
# Willkommensdokument
# ============================================================

set ::welcomeMd {# Markdown Viewer v2

Willkommen zur **mdstack 2.0** Showcase app!

---

## Table of Contents

- [Features](#features)
- [Keyboard Shortcuts](#tastenk-rzel)
- [Suche](#suche)
- [Blockquotes](#blockquotes)
- [Code](#code)
- [Tables](#tabellen)
- [Listen](#listen)

---

## Features

Diese App demonstriert alle mdstack 2.0 Features:

- **TOC-Navigation** – Klicke links im Table of Contents
- **Anchor-Links** – Interne `#`-Links navigieren direkt
- **Volltextsuche** – `Ctrl+F`, mit Highlight und ↑/↓ Navigation
- **Fontsize** – `Ctrl+/−/0` oder Spinbox oben rechts
- **PDF-Export** – `Ctrl+P` (wenn pdf4tcl vorhanden)
- **Link-Handler** – External links open in browser

---

## Keyboard Shortcuts

| Shortcut | Action |
|--------|--------|
| Ctrl+O | Open file |
| Ctrl+R | Neu laden |
| Ctrl+F | Suche ein/aus |
| Ctrl+T | TOC ein/aus |
| Ctrl+P | PDF exportieren |
| Ctrl++ | Increase font |
| Ctrl+- | Decrease font |
| Ctrl+0 | Font normal |
| Escape | Close search |

---

## Suche

Press `Ctrl+F` and search e.g. for **"Tcl"** oder **"Link"**.

Matches are highlighted yellow, the current match orange.
Use ↑ and ↓ to navigate through matches.

---

## Blockquotes

> Dies ist ein einfaches Zitat mit **fetter** und *kursiver* Formatierung.

> **Verschachtelt:**
>
> > Inneres Zitat mit `Inline-Code`.
> > Second line.
>
> Back in outer quote.

---

## Code

### Inline

Use `mdparser::parse` to parse and `mdviewer::render` to display.

### Block

```tcl
package require mdparser 0.2
package require mdviewer 0.3

set ast [mdparser::parse $markdown]
mdviewer::create .v -onlink myHandler
mdviewer::render .v $ast
```

---

## Tables

| Modul | Version | Beschreibung |
|-------|:-------:|-------------|
| mdparser | 0.2 | Markdown → AST |
| mdmodel | 0.1 | AST → Dokumentmodell |
| mdviewer | 0.3 | AST → Tk Text-Widget |
| mdsearch | 0.1 | Volltextsuche + Highlight |
| mdpdf | 0.1 | AST → PDF (pdf4tcl) |

---

## Listen

### Ungeordnet

- Punkt eins
- Punkt zwei mit **Formatierung**
- Punkt drei mit `Code`

### Geordnet

1. Erster Schritt
2. Zweiter Schritt
3. Dritter Schritt

### Tasks

- [x] Parser-Fixes (Phase 1)
- [x] Viewer-Verbesserungen (Phase 2)
- [x] mdsearch Modul (Phase 3)
- [x] Showcase app (v2)
- [ ] Complete documentation

---

## Links

- Internal: Back to [Table of Contents](#table-of-contents)
- Intern: Zu den [Features](#features)
- Extern: [Tcl/Tk Homepage](https://www.tcl.tk/)

---

*Open your own .md file with `Ctrl+O` or via command line!*
}

# ============================================================
# Start
# ============================================================

# Kommandozeilen-Argument?
if {$argc > 0} {
    set argFile [lindex $argv 0]
    if {[file exists $argFile]} {
        cmd::loadFile $argFile
    } else {
        puts stderr "File not found: $argFile"
    }
} else {
    # Willkommensdokument anzeigen
    set ast [mdparser::parse $::welcomeMd]
    set ::currentDoc [mdmodel::new $ast]
    mdviewer::renderModel .pw.viewer.v $::currentDoc
    cmd::updateTOC
    set ::statusText "Welcome – Ctrl+O to open"
}
