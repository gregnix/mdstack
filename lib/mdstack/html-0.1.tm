# mdhtml-0.1.tm -- Markdown AST zu HTML Renderer
#
# CUTOVER 2026-05-06: Adapter zur DocIR-Pipeline.
#
# Diese Datei ist der Ergebnis der mdhtml-Konsolidierung in
# docir-html (Phase 2 Session 7). Public API bleibt
# rückwärtskompatibel — Aufrufer (mdserver, demos, basic.tcl)
# brauchen keine Anpassung. Intern wird die DocIR-Pipeline
# verwendet:
#
#   mdparser-AST → docir-md-source::fromAst → docir-html::render
#
# Optionen wurden 1:1 auf docir-html-Optionen gemappt:
#   -title    → title          (1:1)
#   -css      → cssFile         (1:1)
#   -toc      → includeToc      (Bool-Konvertierung)
#   -lang     → lang            (1:1)
#   -theme    → theme           (1:1)
#   -encoding → ignoriert       (UTF-8 fixed)
#
# Public API:
#   mdstack::html::render  ast ?options?
#   mdstack::html::export  ast outFile ?options?
#   mdstack::html::exportFile mdFile outFile ?options?
#   mdstack::html::escapeHtml text
#   mdstack::html::escapeAttr text
#   mdstack::html::_defaultCss
#
# Die original-V0.1-Implementation liegt als .legacy-Backup falls
# man's bräuchte. Der Cutover wurde in docir-Phase 2 gemacht
# (siehe docir-CHANGES.md).

package provide mdstack::html 0.1

# DocIR-Pipeline laden ueber das Standard Tcl Module System.
# Der Aufrufer muss einen tcl::tm::path konfiguriert haben, in dem
# docir-0.1.tm (Hub) und docir/html-0.1.tm + docir/mdSource-0.1.tm
# auffindbar sind.
package require docir::mdSource
package require docir::html

namespace eval mdstack::html {
    namespace export render export exportFile
}

# ============================================================
# Public API
# ============================================================

# mdstack::html::render ast ?-key value...?
#   Rendert mdparser-AST nach HTML via DocIR-Pipeline
proc mdstack::html::render {ast args} {
    # Optionen parsen (key-value-Liste)
    set opts [dict create \
        -title    "" \
        -css      "" \
        -toc      0 \
        -lang     de \
        -theme    default \
        -encoding utf-8]

    foreach {k v} $args {
        dict set opts $k $v
    }

    # mdparser-AST → DocIR
    set ir [::docir::md::fromAst $ast]

    # docir-html-Optionen aus mdhtml-Optionen ableiten
    set htmlOpts [dict create \
        title       [dict get $opts -title] \
        lang        [dict get $opts -lang] \
        theme       [dict get $opts -theme] \
        includeToc  [expr {[dict get $opts -toc] ? 1 : 0}]]

    # CSS-Datei nur setzen wenn nicht-leer
    set css [dict get $opts -css]
    if {$css ne ""} {
        dict set htmlOpts cssFile $css
    }

    return [::docir::html::render $ir $htmlOpts]
}

# mdstack::html::export ast outFile ?options?
proc mdstack::html::export {ast outFile args} {
    # Optionen: -copyImages (default 1) und -root müssen vor render
    # extrahiert werden, denn render kennt sie nicht.
    set copyImages 1
    set root ""
    set passThrough {}
    foreach {k v} $args {
        switch -- $k {
            -copyImages { set copyImages $v }
            -root       { set root $v }
            default     { lappend passThrough $k $v }
        }
    }

    # Schritt 1: HTML rendern (Pfade unverändert lassen)
    set html [mdstack::html::render $ast {*}$passThrough]

    # Schritt 2: Datei schreiben
    set fh [open $outFile w]
    fconfigure $fh -encoding utf-8
    puts -nonewline $fh $html
    close $fh

    # Schritt 3: Bilder kopieren wenn root + copyImages aktiv
    if {$copyImages && $root ne ""} {
        set destDir [file dirname [file normalize $outFile]]
        set urls [_collectImageUrls $ast]
        _copyAssets $urls $root $destDir
    }

    return $outFile
}

# mdstack::html::exportFile mdFile outFile ?options?
# Setzt -root automatisch auf [file dirname $mdFile] für Asset-Copy.
proc mdstack::html::exportFile {mdFile outFile args} {
    if {![file exists $mdFile]} {
        error "mdstack::html::exportFile: file not found: $mdFile"
    }
    set fh [open $mdFile r]
    fconfigure $fh -encoding utf-8
    set md [read $fh]
    close $fh

    # -root automatisch setzen, falls nicht explizit angegeben
    set hasRoot 0
    foreach {k v} $args {
        if {$k eq "-root"} { set hasRoot 1; break }
    }
    if {!$hasRoot} {
        lappend args -root [file dirname [file normalize $mdFile]]
    }

    set ast [mdstack::parser::parse $md]
    return [mdstack::html::export $ast $outFile {*}$args]
}

# ============================================================
# Asset-Copy: Bilder mit-kopieren beim HTML-Export
# ============================================================

# Sammelt alle relativen Image-URLs aus dem AST.
# Berücksichtigt: Block-image und Inline-image im paragraph (rekursiv).
# Übersprungen: HTTP/HTTPS, file://, absolute Pfade.
proc mdstack::html::_collectImageUrls {ast} {
    set urls {}
    if {[dict exists $ast blocks]} {
        foreach block [dict get $ast blocks] {
            _collectImageUrlsFromBlock $block urls
        }
    }
    return $urls
}

proc mdstack::html::_collectImageUrlsFromBlock {block urlsVar} {
    upvar $urlsVar urls
    set type [dict get $block type]

    # Block-Image
    if {$type eq "image"} {
        if {[dict exists $block url]} {
            set u [dict get $block url]
            if {[_isLocalUrl $u]} { lappend urls $u }
        }
        return
    }

    # Tabelle (mdparser-AST seit A.3 Lesart 2):
    # rekursive Struktur — content ist Liste von tableRow-Knoten, jede
    # tableRow-content ist Liste von tableCell-Knoten, jede tableCell-
    # content ist eine Inline-Liste. Wir descenden vollständig.
    if {$type eq "table"} {
        if {[dict exists $block content]} {
            foreach row [dict get $block content] {
                if {![dict exists $row content]} continue
                foreach cell [dict get $row content] {
                    if {![dict exists $cell content]} continue
                    _collectImageUrlsFromInlines [dict get $cell content] urls
                }
            }
        }
        return
    }

    # Inline-Images im content (paragraph, heading, list-item, etc.)
    if {[dict exists $block content]} {
        _collectImageUrlsFromInlines [dict get $block content] urls
    }

    # Verschachtelte Blocks (list mit items, blockquote, div)
    if {[dict exists $block items]} {
        foreach item [dict get $block items] {
            _collectImageUrlsFromBlock $item urls
        }
    }
    if {[dict exists $block blocks]} {
        foreach sub [dict get $block blocks] {
            _collectImageUrlsFromBlock $sub urls
        }
    }
}

proc mdstack::html::_collectImageUrlsFromInlines {inlines urlsVar} {
    upvar $urlsVar urls
    foreach inline $inlines {
        if {![dict exists $inline type]} continue
        set type [dict get $inline type]
        if {$type eq "image" && [dict exists $inline url]} {
            set u [dict get $inline url]
            if {[_isLocalUrl $u]} { lappend urls $u }
        }
        # Verschachtelte Inlines (strong, emphasis, link)
        if {[dict exists $inline content]} {
            _collectImageUrlsFromInlines [dict get $inline content] urls
        }
        # link-Inline: könnte ein image als label haben
        if {[dict exists $inline label]} {
            _collectImageUrlsFromInlines [dict get $inline label] urls
        }
    }
}

# Lokal = relativ, kein Schema.
proc mdstack::html::_isLocalUrl {url} {
    if {$url eq ""} { return 0 }
    if {[string match "http://*" $url] || \
        [string match "https://*" $url] || \
        [string match "file://*" $url] || \
        [string match "data:*" $url]} { return 0 }
    if {[file pathtype $url] eq "absolute"} { return 0 }
    return 1
}

# Kopiert Asset-Dateien von sourceDir nach destDir, mit
# erhaltener Pfad-Struktur. Überspringt Dateien, die schon
# am Ziel existieren UND identische Größe haben (idempotent).
# Fehler beim einzelnen Kopieren werden geloggt aber nicht
# fatal — Export soll trotzdem durchlaufen.
proc mdstack::html::_copyAssets {urls sourceDir destDir} {
    set copied 0
    set skipped 0
    set missing {}
    foreach url [lsort -unique $urls] {
        set src [file join $sourceDir $url]
        set dst [file join $destDir $url]

        if {![file exists $src]} {
            lappend missing $url
            continue
        }

        # Wenn Quelle und Ziel identisch (gleicher Pfad) — nichts tun
        if {[file normalize $src] eq [file normalize $dst]} {
            incr skipped
            continue
        }

        # Schon vorhanden mit gleicher Größe? → skip
        if {[file exists $dst] && \
            [file size $src] == [file size $dst]} {
            incr skipped
            continue
        }

        # Ziel-Verzeichnis erstellen falls nötig
        set dstDir [file dirname $dst]
        if {![file isdirectory $dstDir]} {
            file mkdir $dstDir
        }

        if {[catch {file copy -force $src $dst} err]} {
            puts stderr "mdhtml: copy failed for '$url': $err"
        } else {
            incr copied
        }
    }
    if {[llength $missing] > 0} {
        puts stderr "mdhtml: [llength $missing] image(s) not found in $sourceDir: [lrange $missing 0 4]..."
    }
    return [list copied $copied skipped $skipped missing [llength $missing]]
}

# ============================================================
# Helper für Aufrufer die direkt darauf zugreifen (mdserver)
# ============================================================

proc mdstack::html::escapeHtml {text} {
    set text [string map {& &amp; < &lt; > &gt; \" &quot;} $text]
    return $text
}

proc mdstack::html::escapeAttr {text} {
    set text [string map {& &amp; \" &quot; ' &#39;} $text]
    return $text
}

# Default CSS für mdserver-Index — minimaler Stub.
# (mdserver nutzt das nur in der index-Methode für Verzeichnis-
# Listings, nicht für Markdown-Rendering selbst.)
proc mdstack::html::_defaultCss {} {
    return {
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
               max-width: 50em; margin: 2em auto; padding: 0 1em;
               line-height: 1.5; color: #222; }
        h1 { font-size: 1.6em; border-bottom: 2px solid #888; padding-bottom: 0.2em; }
        h2 { font-size: 1.3em; border-bottom: 1px solid #ccc; padding-bottom: 0.15em; }
        a { color: #0055aa; }
        a:hover { text-decoration: underline; }
        ul { padding-left: 1.5em; }
        li { margin: 0.15em 0; }
    }
}
