# mdserver-0.4.tm -- Markdown-Web-Server Modul (coroutine/non-blocking)
# ============================================================================
# HTTP/HTTPS server for Markdown documents.
# No Tk, no fonts, no display. Requires only Tcl 8.6+.
#
# Classes:
#   mdserver::Request  -- parse an HTTP request
#   mdserver::Renderer -- Markdown + index -> HTML
#   mdserver::Server   -- HTTP/HTTPS server
#
# Requires: mdstack::parser 0.2, mdstack::html 0.1
# Optional: mdstack::theme 0.1, tls (for HTTPS)
# ============================================================================

package provide mdserver 0.4

# Der Server-Kopf kommt aus der Paketfassung, nicht aus drei getippten Zahlen.
# Bis 0.3 stand in derselben Datei zweimal "mdserver/0.5", einmal
# "mdserver/0.4" und einmal "mdserver 0.4" -- bei Paketfassung 0.3. Keine der
# Angaben stimmte, und keine stimmte mit einer anderen ueberein.
namespace eval ::mdserver {
    variable serverHeader "mdserver/[package provide mdserver]"
}

package require Tcl 8.6 9
# ============================================================
# Load modules
# ============================================================

if {[catch {package require mdstack::parser 0.2} err]} {
    puts stderr "ERROR: mdparser 0.2 not found: $err"
    exit 1
}
if {[catch {package require mdstack::html 0.1} err]} {
    puts stderr "ERROR: mdhtml 0.1 not found: $err"
    exit 1
}
if {[catch {package require mdstack::theme 0.1} err]} {
    # Optional: without it the pages fall back to the docir default CSS,
    # i.e. --theme has no effect.
    puts stderr "WARNING: mdstack::theme 0.1 not found -- themes disabled: $err"
}

# ============================================================
# MIME types (global, immutable)
# ============================================================

namespace eval mdserver {
    variable moduleDir [file dirname [file normalize [info script]]]
    variable mimeTypes {
        .html  "text/html; charset=utf-8"
        .htm   "text/html; charset=utf-8"
        .css   "text/css; charset=utf-8"
        .js    "application/javascript; charset=utf-8"
        .json  "application/json"
        .txt   "text/plain; charset=utf-8"
        .md    "text/plain; charset=utf-8"
        .png   "image/png"
        .jpg   "image/jpeg"
        .jpeg  "image/jpeg"
        .gif   "image/gif"
        .svg   "image/svg+xml"
        .ico   "image/x-icon"
        .pdf   "application/pdf"
    }
}

# ============================================================
# Coroutine-aware, non-blocking gets.
# Returns the line length, -1 on EOF/timeout. Yields until a
# complete line is available -- the readable event (or the timeout)
# resumes the coroutine. A slow connection never blocks the others.
# ============================================================
# max > 0: bricht ab, sobald mehr als max Bytes ohne Zeilenende im Puffer
# liegen -- Rueckgabe -2. Die Pruefung muss VOR dem Warten stehen und am
# Puffer haengen, nicht an der fertigen Zeile: eine Zeile ohne \n waechst
# sonst unbegrenzt, und genau das soll die Grenze verhindern.
proc mdserver::coGets {chan _line {max 0}} {
    upvar 1 $_line line
    while {1} {
        set n [gets $chan line]
        if {$n >= 0} {
            if {$max > 0 && $n > $max} { return -2 }
            return $n
        }
        if {[eof $chan]} { return -1 }
        if {$max > 0 && [chan pending input $chan] > $max} { return -2 }
        if {[yield] eq "TIMEOUT"} { return -1 }
    }
}

# ============================================================
# mdserver::Request -- parse an HTTP request
# ============================================================

oo::class create mdserver::Request {

    variable _method _path _query _headers _params

    # maxline: Bytes je Zeile (Anfragezeile und jede Kopfzeile).
    # maxheader: Summe aller Kopfzeilen. 0 heisst ohne Grenze.
    # Beide mit Vorgabe, damit vorhandene Aufrufe unveraendert bleiben.
    constructor {chan {maxline 8190} {maxheader 16384}} {
        set _method  ""
        set _path    ""
        set _query   ""
        set _headers {}
        set _params  {}
        my _parse $chan $maxline $maxheader
    }

    # Public accessors
    method method  {} { return $_method  }
    method path    {} { return $_path    }
    method query   {} { return $_query   }
    method headers {} { return $_headers }
    method params  {} { return $_params  }

    method header {name} {
        set key [string tolower $name]
        if {[dict exists $_headers $key]} {
            return [dict get $_headers $key]
        }
        return ""
    }

    method param {name {default ""}} {
        if {[dict exists $_params $name]} {
            return [dict get $_params $name]
        }
        return $default
    }

    # Private: read request line + headers
    method _parse {chan maxline maxheader} {
        # Request line (coroutine, non-blocking)
        set n [mdserver::coGets $chan requestLine $maxline]
        if {$n == -2} { throw {MDDOCS URITOOLONG} "request line over $maxline bytes" }
        if {$n < 0}   { throw {MDDOCS BADREQUEST} {connection closed/timeout} }

        # Headers until blank line
        set summe 0
        while {1} {
            set n [mdserver::coGets $chan line $maxline]
            if {$n == -2} { throw {MDDOCS HEADERTOOBIG} "header line over $maxline bytes" }
            if {$n < 0} break
            set line [string trimright $line]
            if {$line eq ""} break
            incr summe [string length $line]
            if {$maxheader > 0 && $summe > $maxheader} {
                throw {MDDOCS HEADERTOOBIG} "headers over $maxheader bytes"
            }
            if {[regexp {^([^:]+):\s*(.*)$} $line -> k v]} {
                dict set _headers [string tolower $k] $v
            }
        }

        # Method + URL
        #
        # Zwei verschiedene Faelle, die bis 0.3.1 beide gleich endeten -- die
        # Verbindung wurde ohne Antwort geschlossen, der Klient sah "empty
        # reply". Ein POST ist aber kein kaputter Aufruf, sondern ein
        # verstandener mit einer Methode, die es hier nicht gibt: 405 mit
        # "Allow: GET, HEAD" (RFC 9110 15.5.6).
        if {![regexp {^(GET|HEAD)\s+(/[^\s]*)\s+HTTP} $requestLine \
                -> _method rawUrl]} {
            if {[regexp {^([A-Z]+)\s+(/[^\s]*)\s+HTTP} $requestLine -> m u]} {
                set _method $m
                set _path $u
                # Die Methode steht im Fehlercode, der Pfad in der Meldung:
                # geworfen wird hier im Konstruktor, also gibt es noch kein
                # Request-Objekt, an dem der Aufrufer den Pfad ablesen koennte.
                throw [list MDDOCS METHOD $m] $u
            }
            throw {MDDOCS BADREQUEST} "Invalid request line: $requestLine"
        }

        # Split URL and query
        if {[string first ? $rawUrl] >= 0} {
            regexp {^([^?]*)(\?(.*))?$} $rawUrl -> _path _ _query
        } else {
            set _path $rawUrl
        }
        set _path   [my _urlDecode $_path]
        set _params [my _parseQuery $_query]
    }

    method _urlDecode {str} {
        set str [string map {+ " "} $str]
        regsub -all {%([0-9A-Fa-f]{2})} $str {[binary format H2 \1]} str
        set str [subst $str]
        return [encoding convertfrom utf-8 $str]
    }

    method _parseQuery {query} {
        set result {}
        foreach pair [split $query &] {
            if {$pair eq ""} continue
            set kv [split $pair =]
            set k [my _urlDecode [lindex $kv 0]]
            set v [my _urlDecode [lindex $kv 1]]
            dict set result $k $v
        }
        return $result
    }
}

# ============================================================
# mdserver::Renderer -- Markdown + index -> HTML
# ============================================================

oo::class create mdserver::Renderer {

    variable _title

    constructor {title} {
        set _title $title
    }

    method markdown {path theme toc {cssFile ""}} {
        set md [my _readFile $path]
        set ast [mdstack::parser::parse $md]
        set html [mdstack::html::render $ast -theme $theme -toc $toc -lang de]
        set html [my _injectTheme $html $theme]
        return [my _injectCss $html $cssFile]
    }

    # Insert the theme CSS as an extra <style> after the default one.
    #
    # The theme name is passed down to docir::html, but that only knows its own
    # default CSS ("manpage" | "none" | default) -- hell / dunkel / solarized
    # mean nothing to it, so every page would come out identical. The theme's
    # own CSS (mdstack::theme::toCSS) is therefore appended here: same
    # specificity, later rule wins.
    #
    # Degrades silently: no mdstack::theme package, or an unknown theme name,
    # leaves the page with the default CSS instead of throwing.
    method _injectTheme {html theme} {
        if {$theme eq "" || $theme eq "none"} { return $html }
        set css ""
        if {[catch { set css [mdstack::theme::toCSS $theme] }]} { return $html }
        if {[string trim $css] eq ""} { return $html }
        return [my _insertStyle $html "<style>\n$css\n</style>\n"]
    }

    # Insert the chosen style as an extra <style> after the theme --
    # render has no -css; the style rules win via the CSS cascade.
    method _injectCss {html cssFile} {
        if {$cssFile eq "" || ![file exists $cssFile]} { return $html }
        set css ""
        catch { set css [my _readFile $cssFile] }
        if {$css eq ""} { return $html }
        return [my _insertStyle $html "<style>\n$css\n</style>\n"]
    }

    # Put a <style> block at the end of <head> (else before </body>, else last).
    method _insertStyle {html block} {
        set idx [string first "</head>" $html]
        if {$idx < 0} { set idx [string first "</body>" $html] }
        if {$idx >= 0} {
            return "[string range $html 0 [expr {$idx - 1}]]$block[string range $html $idx end]"
        }
        return "$html$block"
    }

    # Directory listing (when a directory has no index.md): build a small
    # Markdown document and render it through mdstack -- the same path every
    # other page uses, so the look stays consistent (no hand-built HTML).
    method index {dirPath urlPath theme {cssFile ""}} {
        set base [string trimright $urlPath /]
        set h1 [expr {$base eq "" ? $_title : "[file tail $base]/"}]

        set items {}
        if {$urlPath ne "/"} {
            lappend items "- \[..\](../)"
        }
        foreach d [lsort [glob -nocomplain -directory $dirPath -type d *]] {
            set name [file tail $d]
            if {$name in {. ..}} continue
            lappend items "- \[$name/\]($name/)"
        }
        foreach f [lsort [glob -nocomplain -directory $dirPath *.md]] {
            lappend items "- \[[my _mdTitle $f]\]([file tail $f])"
        }

        set md "# $h1

"
        if {[llength $items] == 0} {
            append md "_No documents found._
"
        } else {
            append md [join $items "
"] "
"
        }

        set ast  [mdstack::parser::parse $md]
        set html [mdstack::html::render $ast -theme $theme -toc 0 -lang de]
        set html [my _injectTheme $html $theme]
        return [my _injectCss $html $cssFile]
    }

    # Site index: all .md under rootDir as a recursive tree.
    method siteIndex {rootDir theme {cssFile ""}} {
        set md "# Alle Dokumente\n\n"
        set tree [my _tree $rootDir $rootDir 0]
        if {[string trim $tree] eq ""} {
            append md "_Keine Markdown-Dokumente gefunden._\n"
        } else {
            append md $tree
        }
        set ast [mdstack::parser::parse $md]
        set html [mdstack::html::render $ast -theme $theme -toc 0 -lang de]
        set html [my _injectTheme $html $theme]
        return [my _injectCss $html $cssFile]
    }

    # Recursive Markdown list (directories bold, .md as links).
    method _tree {rootDir dir depth} {
        set out ""
        set pad [string repeat "  " $depth]
        foreach sub [lsort [glob -nocomplain -type d -directory $dir *]] {
            if {[file tail $sub] in {. ..}} continue
            append out "$pad- **[file tail $sub]/**\n"
            append out [my _tree $rootDir $sub [expr {$depth + 1}]]
        }
        foreach fpath [lsort [glob -nocomplain -type f -directory $dir *.md]] {
            set rel   [my _relUrl $rootDir $fpath]
            set title [my _mdTitle $fpath]
            append out "$pad- \[$title\]\($rel\)\n"
        }
        return $out
    }

    # Server URL of a file relative to the root.
    method _relUrl {rootDir fpath} {
        set rel [string range $fpath [string length $rootDir] end]
        return "/[string trimleft $rel /]"
    }

    # Title = first H1, else file name.
    method _mdTitle {fpath} {
        set title [file tail $fpath]
        if {![catch {open $fpath r} fh]} {
            fconfigure $fh -encoding utf-8
            while {[gets $fh line] >= 0} {
                if {[regexp {^#\s+(.+)$} $line -> t]} {
                    set title [string trim $t]; break
                }
            }
            close $fh
        }
        return $title
    }

    method _readFile {path} {
        set fh [open $path r]
        fconfigure $fh -encoding utf-8
        try {
            return [read $fh]
        } finally {
            close $fh
        }
    }
}

# ============================================================
# mdserver::Server -- HTTP/HTTPS server
# ============================================================

oo::class create mdserver::Server {

    variable _cfg _renderer _httpSock _httpsSock _connSeq _conns _ctrlSock

    constructor {args} {
        # Defaults
        array set opts {
            port    8080
            bind    ""
            dotfiles 0
            trustedproxy ""
            maxline    8190
            maxheader  16384
            healthpath "/__mdserver/health"

            root    "."
            theme   "hell"
            title   "mdserver"
            index   "index.md"
            nav     1
            toc     1
            log     1
            cert    ""
            key     ""
            tlsport 8443
            timeout 15000
            control ""
            style      "plain"
            stylesdir  ""
            navbg      "#2c3e50"
            navfg      "#ffffff"
            navlinks   {{{&#127968; Start} /} {{&#128218; Alle Dokumente} /?nav=index}}
            navsections 1
            navmax      6
            navmore     "&#128193; Bereiche"
            chapternav  1
        }
        # Read arguments
        foreach {k v} $args {
            set opts([string trimleft $k -]) $v
        }
        set opts(root) [file normalize $opts(root)]
        set opts(tls)  0
        set _cfg [array get opts]

        set _renderer [mdserver::Renderer new [my cfg title]]
        set _httpSock  ""
        set _httpsSock ""
        set _connSeq   0
        set _conns     {}
        set _ctrlSock  ""
        set ::mdserver::running 1
    }

    destructor {
        my stop
        $_renderer destroy
    }

    # Config accessor
    method cfg {key} {
        return [dict get $_cfg $key]
    }

    # Start the server
    method start {} {
        # Load TLS optionally
        if {[my cfg cert] ne "" && [my cfg key] ne ""} {
            if {[catch {package require tls} err]} {
                puts stderr "WARNING: tls not available -- HTTPS disabled: $err"
            } else {
                dict set _cfg tls 1
            }
        }

        # HTTP
        #
        # bind: an welche Adresse. Leer heisst alle Schnittstellen -- das war
        # bis 0.3.1 die einzige Moeglichkeit, und der Steuerport war die
        # einzige Stelle mit -myaddr. Steht mdserver hinter einem nginx, das
        # die Anmeldung macht, muss der HTTP-Port auf 127.0.0.1 liegen: sonst
        # ist er von aussen offen UND unangemeldet, und die Anmeldung haengt
        # allein an der Firewall. (Ein LAN-Konzept vom 28.09.2026 nannte eine
        # Option --bind, die es damals nicht gab.)
        set myaddr {}
        if {[my cfg bind] ne ""} { set myaddr [list -myaddr [my cfg bind]] }
        try {
            set _httpSock [socket -server [list [self object] handleRequest] \
                {*}$myaddr [my cfg port]]
        } on error {err} {
            set wo [expr {[my cfg bind] eq "" ? "" : " on [my cfg bind]"}]
            error "Cannot bind to HTTP port [my cfg port]$wo: $err"
        }

        # HTTPS
        if {[my cfg tls]} {
            if {![file exists [my cfg cert]]} {
                error "Certificate not found: [my cfg cert]"
            }
            if {![file exists [my cfg key]]} {
                error "Key not found: [my cfg key]"
            }
            try {
                tls::init \
                    -certfile [my cfg cert] \
                    -keyfile  [my cfg key]  \
                    -ssl2 0 -ssl3 0 -tls1 0 -tls1.2 1

                set _httpsSock [tls::socket \
                    -server [list [self object] handleRequest] \
                    -command [list [self object] tlsEvent] \
                    {*}$myaddr [my cfg tlsport]]
            } on error {err} {
                error "Cannot start HTTPS on port [my cfg tlsport]: $err"
            }
        }

        # Control port (localhost only) -- clean stop/reload without PID lookup
        if {[my cfg control] ne ""} {
            if {[catch {
                set _ctrlSock [socket -server [list [self object] controlAccept] \
                    -myaddr 127.0.0.1 [my cfg control]]
            } err]} {
                puts stderr "WARNING: control port [my cfg control] not bound: $err"
            }
        }

        my _printStatus
    }

    method stop {} {
        catch { close $_httpSock  }
        catch { close $_httpsSock }
        catch { close $_ctrlSock  }
        foreach ch [dict keys $_conns] { catch { close $ch } }
        set _conns {}
    }

    # Style name (?style=) -> path to a CSS file in styles/, or "" (default).
    # sidebar | sticky | collapsible ; anything else = no extra CSS (plain).
    method _styleCss {style} {
        set dir [my cfg stylesdir]
        if {$dir eq ""} { set dir [file join $::mdserver::moduleDir .. styles] }
        switch -- $style {
            sidebar     { set f sidebar.css }
            sticky      { set f sticky-top.css }
            collapsible { set f collapsible.css }
            default     { return "" }
        }
        set p [file normalize [file join $dir $f]]
        return [expr {[file exists $p] ? $p : ""}]
    }

    # Insert the nav bar (Start + site index) at the top of every page.
    # Top-level sections of the doc root as {label url} pairs, for the nav bar.
    # A section is shown if it (transitively) contains any .md; the label is the
    # section index.md H1, else the folder name.
    method _sectionLinks {} {
        set out {}
        set root [my cfg root]
        foreach d [lsort -dictionary [glob -nocomplain -directory $root -type d *]] {
            set name [file tail $d]
            if {[string index $name 0] eq "."} continue
            if {![my _dirHasAnyMd $d]} continue
            set label $name
            set idx [file join $d index.md]
            if {[file exists $idx]} {
                set t [my _h1Title $idx]
                if {$t ne ""} { set label $t }
            }
            set label [string map {& &amp; < &lt; > &gt;} $label]
            lappend out [list $label "/$name/"]
        }
        return $out
    }

    # True if $dir contains any .md file (transitively).
    method _dirHasAnyMd {dir} {
        if {[llength [glob -nocomplain -directory $dir *.md]] > 0} { return 1 }
        foreach d [glob -nocomplain -directory $dir -type d *] {
            if {[string index [file tail $d] 0] eq "."} continue
            if {[my _dirHasAnyMd $d]} { return 1 }
        }
        return 0
    }

    # First "# H1" of a Markdown file, or "" if none.
    method _h1Title {file} {
        set title ""
        if {![catch {open $file r} fh]} {
            fconfigure $fh -encoding utf-8
            while {[gets $fh line] >= 0} {
                if {[regexp {^#\s+(.+)$} $line -> t]} {
                    set title [string trim $t]; break
                }
            }
            close $fh
        }
        return $title
    }

    # Chapter list of a bookkit book (dir with book.tcl): the "chapters" list
    # from book.tcl (safe interp), else numeric-prefix order.
    method _bookChapters {dir} {
        set chapters {}
        set bt [file join $dir book.tcl]
        if {[file exists $bt]} {
            set ip [interp create -safe]
            interp eval $ip {set chapters {}}
            catch {
                set fh [open $bt r]; fconfigure $fh -encoding utf-8
                set script [read $fh]; close $fh
                interp eval $ip $script
                set chapters [interp eval $ip {set chapters}]
            }
            interp delete $ip
        }
        if {[llength $chapters] == 0} {
            # bookkit web-index block in index.md: reuse its chapter links.
            set idx [file join $dir index.md]
            if {[file exists $idx]} {
                set fh [open $idx r]; fconfigure $fh -encoding utf-8
                set text [read $fh]; close $fh
                if {[regexp {<!-- bookkit:toc:begin -->(.*?)<!-- bookkit:toc:end -->} $text -> blk]} {
                    foreach {full url} [regexp -all -inline {\]\(([^)]+\.md)\)} $blk] {
                        if {![string match "*/*" $url] && ![string match "http*" $url]} {
                            lappend chapters $url
                        }
                    }
                }
            }
        }
        if {[llength $chapters] == 0} { set chapters [my _prefixOrdered $dir] }
        return $chapters
    }

    # A directory is treated as a book if it has book.tcl or its index.md
    # carries a bookkit web-index block.
    method _isBookDir {dir} {
        if {[file exists [file join $dir book.tcl]]} { return 1 }
        set idx [file join $dir index.md]
        if {[file exists $idx]} {
            set fh [open $idx r]; fconfigure $fh -encoding utf-8
            set text [read $fh]; close $fh
            if {[string first "<!-- bookkit:toc:begin -->" $text] >= 0} { return 1 }
        }
        return 0
    }

    # Sidebar book navigation: the full chapter list (current one highlighted).
    # Only in sidebar style and inside a book.
    method _injectBookNav {html fsPath style} {
        if {$style ne "sidebar"} { return $html }
        set dir [file dirname $fsPath]
        if {![my _isBookDir $dir]} { return $html }
        set chapters [my _bookChapters $dir]
        if {[llength $chapters] == 0} { return $html }
        set cur [file tail $fsPath]
        set items ""
        foreach ch $chapters {
            set label [my _chapterLabel [file join $dir $ch]]
            set cls [expr {$ch eq $cur ? " class=\"cur\"" : ""}]
            append items "<li$cls><a href=\"$ch\">$label</a></li>"
        }
        set nav "<nav class=\"mdserver-booknav\">\
<input type=\"checkbox\" id=\"mdserver-booknav-toggle\" class=\"booknav-toggle\">\
<label for=\"mdserver-booknav-toggle\" class=\"booknav-toggle-label\">&#128214; Kapitel</label>\
<div class=\"booknav-title\"><a href=\"index.md\">&uarr; &Uuml;bersicht</a></div>\
<ul>$items</ul></nav>\n"
        if {[regexp -indices {<body[^>]*>} $html m]} {
            set e [lindex $m 1]
            return "[string range $html 0 $e]\n$nav[string range $html [expr {$e+1}] end]"
        }
        return "$nav$html"
    }

    # *.md ordered by numeric prefix (index.md / indexsub.md excluded).
    method _prefixOrdered {dir} {
        set withNum {}; set noNum {}
        foreach fp [glob -nocomplain -directory $dir *.md] {
            set name [file tail $fp]
            if {$name in {index.md indexsub.md}} continue
            if {[regexp {^(\d+)} $name -> p]} {
                lappend withNum [list [scan $p %d] $name]
            } else {
                lappend noNum $name
            }
        }
        set out {}
        foreach pair [lsort -integer -index 0 $withNum] { lappend out [lindex $pair 1] }
        foreach fp [lsort $noNum] { lappend out $fp }
        return $out
    }

    # Chapter link label: cleaned H1, else file base name (HTML-escaped).
    method _chapterLabel {file} {
        set t [my _h1Title $file]
        if {$t eq ""} { set t [file rootname [file tail $file]] }
        regsub -all {\[([^\]]*)\]\{[^\}]*\}} $t {\1} t
        regsub -all {\[([^\]]*)\]\([^)]*\)} $t {\1} t
        regsub -all {\{[^\}]*\}} $t {} t
        return [string map {& &amp; < &lt; > &gt;} [string trim $t]]
    }

    # In a book (dir with book.tcl), append a prev / up / next chapter bar to a
    # chapter page. index.md and non-chapter files are left unchanged.
    method _injectChapterNav {html fsPath} {
        if {![my cfg chapternav]} { return $html }
        set dir  [file dirname $fsPath]
        set name [file tail $fsPath]
        if {$name eq "index.md"} { return $html }
        if {![my _isBookDir $dir]} { return $html }
        set chapters [my _bookChapters $dir]
        set i [lsearch -exact $chapters $name]
        if {$i < 0} { return $html }

        set link {color:#0055aa;text-decoration:none;}
        if {$i > 0} {
            set p [lindex $chapters [expr {$i - 1}]]
            set prev "<a href=\"$p\" style=\"$link\">&larr; [my _chapterLabel [file join $dir $p]]</a>"
        } else { set prev "<span></span>" }
        if {$i < [expr {[llength $chapters] - 1}]} {
            set n [lindex $chapters [expr {$i + 1}]]
            set next "<a href=\"$n\" style=\"$link\">[my _chapterLabel [file join $dir $n]] &rarr;</a>"
        } else { set next "<span></span>" }
        set up "<a href=\"index.md\" style=\"$link\">&uarr; &Uuml;bersicht</a>"

        set bar "<nav class=\"mdserver-chapnav\" style=\"display:flex;\
justify-content:space-between;align-items:center;gap:1em;\
margin:2.5em 0 0;padding:0.8em 0;border-top:1px solid #ccc;font-size:0.95em;\">\
$prev$up$next</nav>\n"

        set idx [string first "</body>" $html]
        if {$idx >= 0} {
            return "[string range $html 0 [expr {$idx - 1}]]$bar[string range $html $idx end]"
        }
        return "$html$bar"
    }

    # One nav bar link. Never wraps inside itself -- a label breaks the bar
    # between links, not inside a title.
    method _navLink {label url fg} {
        return "<a href=\"$url\" style=\"color:$fg;text-decoration:none;white-space:nowrap;\">$label</a>"
    }

    # Sections folded into one CSS-only dropdown (no JavaScript: details/summary).
    method _navDropdown {sections bg fg} {
        set items ""
        foreach link $sections {
            lassign $link label url
            append items [my _navLink $label $url $fg]
        }
        set label [my cfg navmore]
        return "<details class=\"mdserver-navmore\">\
<summary style=\"color:$fg;\">$label</summary>\
<div class=\"mdserver-navmore-items\">$items</div></details>"
    }

    # Stylesheet for the nav bar: wrapping as a safety net, plus the dropdown.
    method _navCss {bg fg} {
        set css {
.mdserver-nav { flex-wrap: wrap; row-gap: 0.4em; }
.mdserver-navmore { position: relative; }
.mdserver-navmore > summary { cursor: pointer; list-style: none; white-space: nowrap; }
.mdserver-navmore > summary::-webkit-details-marker { display: none; }
.mdserver-navmore-items { display: none; position: absolute; top: 1.8em; left: 0;
    z-index: 100; flex-direction: column; gap: 0.5em; padding: 0.7em 1em;
    min-width: 14em; border-radius: 0 0 4px 4px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.28);
    background: __BG__; color: __FG__; }
.mdserver-navmore[open] > .mdserver-navmore-items { display: flex; }
}
        return "<style>[string map [list __BG__ $bg __FG__ $fg] $css]</style>"
    }

    method _injectNav {html} {
        if {![my cfg nav]} { return $html }
        set bg [my cfg navbg]
        set fg [my cfg navfg]
        # Links from config: a list of {label url} pairs.
        set links ""
        foreach link [my cfg navlinks] {
            lassign $link label url
            append links [my _navLink $label $url $fg]
        }
        # Top-level sections, auto-derived from the document root. More than
        # navmax of them are folded into a single dropdown, so the bar stays
        # one line however many sections the root grows. navmax 0 = never fold.
        set css ""
        if {[my cfg navsections]} {
            set sections [my _sectionLinks]
            set max      [my cfg navmax]
            if {![string is integer -strict $max]} { set max 0 }
            if {$max > 0 && [llength $sections] > $max} {
                append links [my _navDropdown $sections $bg $fg]
                set css [my _navCss $bg $fg]
            } else {
                foreach link $sections {
                    lassign $link label url
                    append links [my _navLink $label $url $fg]
                }
            }
        }
        set style "background:$bg;color:$fg;padding:0.5em 1em;\
margin:0 calc(50% - 50vw) 1em;width:100vw;box-sizing:border-box;\
font-size:0.95em;display:flex;gap:1.4em;align-items:center;align-self:start;\
flex-wrap:wrap;row-gap:0.4em;"
        set bar "$css<nav class=\"mdserver-nav\" style=\"$style\">$links</nav>
"
        if {[regexp -indices {<body[^>]*>} $html m]} {
            set e [lindex $m 1]
            return "[string range $html 0 $e]
$bar[string range $html [expr {$e + 1}] end]"
        }
        return "$bar$html"
    }

    # Clean shutdown: close listeners + open connections, end the loop.
    # Sauber beenden: nur die HORCHSOCKETS zu, damit keine neue Verbindung
    # mehr dazukommt. Laufende Antworten bleiben stehen -- auf die wartet
    # _beendeSanft.
    #
    # Bis 0.4 rief shutdown my stop, und das schliesst alle offenen
    # Verbindungen sofort und leert _conns. Danach kann kein Warten mehr
    # greifen: wer gerade eine grosse PDF holte, bekam sie mitten im Byte
    # abgeschnitten, und zwar bei jedem systemctl restart.
    method shutdown {} {
        catch { close $_httpSock  }
        catch { close $_httpsSock }
        catch { close $_ctrlSock  }
        set _httpSock  ""
        set _httpsSock ""
        set _ctrlSock  ""
        catch { set ::mdserver::running 0 }
    }

    # Eine Antwort auf den Steuerport -- blockierend geschrieben.
    #
    # Das ist eine Haertung, KEINE Fehlerbehebung: 0.3.4 hat hier schon
    # richtig geantwortet. Dass es zunaechst anders aussah, lag am Klienten,
    # nicht am Server -- OpenBSD-netcat, das Standard-nc auf Debian, schliesst
    # die Senderichtung nach EOF auf stdin nicht und wartet weiter:
    #
    #     echo ping | nc    127.0.0.1 8099   -> leer, laeuft in den Timeout
    #     echo ping | nc -N 127.0.0.1 8099   -> pong
    #
    # Deshalb liegt mdctl.tcl daneben, und deshalb steht in der Startmeldung
    # nicht mehr "echo stop | nc". Hier sind es wenige Bytes auf eine
    # Loopback-Verbindung und der Steuerport ist kein Lastpfad, also ist
    # blockierend einfacher und ohne Nachteil.
    method _ctrlAntwort {chan text} {
        catch {
            fconfigure $chan -blocking 1
            puts $chan $text
            flush $chan
        }
        catch {close $chan}
    }

    # Laufende Antworten zu Ende bringen, dann beenden. Ein hartes exit mitten
    # in einer grossen PDF liefert dem Leser eine halbe Datei.
    method _beendeSanft {{restMs 5000}} {
        if {[dict size $_conns] == 0} {
            my _log "shutdown: fertig"
            exit 0
        }
        if {$restMs <= 0} {
            my _log "shutdown: [dict size $_conns] Verbindung(en) abgeschnitten"
            my stop
            exit 0
        }
        # namespace code, nicht [list [self object] _beendeSanft ...]: eine
        # private Methode ist von aussen nicht aufrufbar, und ein after-Skript
        # laeuft aussen. Gemessen als
        #   Background error: unknown method "_beendeSanft"
        after 100 [namespace code [list my _beendeSanft [expr {$restMs - 100}]]]
    }

    # Control connection (localhost): one line, one command (stop|ping).
    method controlAccept {chan addr port} {
        fconfigure $chan -blocking 0 -buffering line -translation crlf
        fileevent $chan readable [list [self object] controlRead $chan]
    }
    method controlRead {chan} {
        if {[catch {gets $chan line} n] || $n < 0} {
            if {[eof $chan]} { catch {close $chan} }
            return
        }
        set cmd [string tolower [string trim $line]]
        switch -- $cmd {
            stop {
                my _ctrlAntwort $chan "stopping"
                my _log "control: stop"
                my shutdown
                my _beendeSanft
            }
            ping    { my _ctrlAntwort $chan "pong" }
            default { my _ctrlAntwort $chan "commands: stop ping" }
        }
    }

    # Accept callback -- one coroutine per connection (non-blocking)
    method handleRequest {chan addr port} {
        coroutine ::mdserver::conn[incr _connSeq] [self object] serveConn $chan $addr $port
    }

    # TLS events: silently drop handshake errors from broken connections
    # (e.g. non-TLS clients on the HTTPS port), no stderr noise.
    method tlsEvent {command args} {
        switch -- $command {
            verify  { return 1 }
            error   -
            info    -
            default { return }
        }
    }

    # Serve the connection -- runs as a coroutine
    method serveConn {chan addr port} {
        chan configure $chan -blocking 0 -buffering full \
            -translation crlf -encoding utf-8
        dict set _conns $chan 1
        # readable event resumes this coroutine; timeout guards against slow-loris
        chan event $chan readable [info coroutine]
        set tid [after [my cfg timeout] [list catch [list [info coroutine] TIMEOUT]]]

        # Fuer die Protokollzeile, die am Ende entsteht. Ohne verstandene
        # Anfragezeile bleibt es bei "- -".
        set woher   $addr
        set methode "-"
        set pfad    "-"

        try {
            set req [mdserver::Request new $chan [my cfg maxline] [my cfg maxheader]]
            after cancel $tid
            chan event $chan readable {}

            # HEAD: derselbe Kopf wie bei GET, aber kein Koerper (RFC 9110
            # 9.3.2). Der Merker haengt am Kanal, siehe _koerper.
            variable _nurKopf
            set _nurKopf($chan) [expr {[$req method] eq "HEAD"}]

            set xff [string trim [my _woher $addr $req]]
            if {$xff ne ""} { set woher $xff }
            set methode [$req method]
            set pfad    [$req path]

            set theme [$req param theme [my cfg theme]]
            set toc   [$req param toc   [my cfg toc]]
            set style [$req param style [my cfg style]]
            set path  [$req path]

            my _dispatch $chan $req $path $theme $toc $style

        } trap {MDDOCS METHOD} {u opts} {
            set methode [lindex [dict get $opts -errorcode] 2]
            set pfad    $u
            my _send $chan "405 Method Not Allowed" "text/html; charset=utf-8" \
                "<html><body><h1>405 Method Not Allowed</h1><p>mdserver liest nur: GET, HEAD.</p></body></html>" \
                {Allow {GET, HEAD}}
        } trap {MDDOCS URITOOLONG} {m} {
            if {$methode eq "-"} { set methode "?" }
            # Eine ueberlange Anfragezeile: der Klient soll es erfahren, nicht
            # raten. 414, und der Puffer waechst nicht weiter (RFC 9110 15.5.15).
            my _notiz $chan $m
            my _send $chan "414 URI Too Long" "text/html; charset=utf-8" \
                "<html><body><h1>414 URI Too Long</h1></body></html>"
        } trap {MDDOCS HEADERTOOBIG} {m} {
            if {$methode eq "-"} { set methode "?" }
            my _notiz $chan $m
            my _send $chan "431 Request Header Fields Too Large" "text/html; charset=utf-8" \
                "<html><body><h1>431 Request Header Fields Too Large</h1></body></html>"
        } trap {MDDOCS BADREQUEST} {} {
            # Broken connection / timeout / invalid request -- ignore silently
        } on error {msg} {
            my _notiz $chan "bgerror: $msg"
            puts stderr "mdserver bgerror: $msg"
        } finally {
            after cancel $tid
            # Eine Zeile je Anfrage, erst hier: vorher sind Status und Bytes
            # nicht bekannt. Eine Verbindung ohne verstandene Anfragezeile
            # (BADREQUEST) bekommt keine -- da gibt es nichts zu protokollieren.
            if {$methode ne "-"} { my _zeile $chan $woher $methode $pfad }
            my _zeileWeg $chan
            variable _nurKopf
            unset -nocomplain _nurKopf($chan)
            my _flushClose $chan
        }
    }

    # Wer hat geholt? Hinter einem Proxy steht als Gegenstelle immer dessen
    # Adresse, also braucht man X-Forwarded-For -- aber den setzt der Proxy
    # nur DAVOR, anhaengen kann ihn jeder. Bis 0.3.1 glaubte mdserver ihn
    # ungeprueft: ein direktes
    #
    #     curl -H "X-Forwarded-For: 9.9.9.9" http://server:8080/
    #
    # schrieb 9.9.9.9 ins Protokoll. Eine falsche Angabe ist schlechter als
    # keine. Seit 0.3.2 wird der Kopf nur gelesen, wenn die GEGENSTELLE in
    # --trusted-proxy steht; Vorgabe leer heisst: gar nicht.
    #
    # Verglichen wird auf genaue Uebereinstimmung, keine Netzmasken -- ein
    # halb verstandenes CIDR waere hier schlimmer als keins. Wer dem Loopback
    # traut, traut damit allem, was auf demselben Rechner laeuft.
    method _woher {addr req} {
        if {[lsearch -exact [my cfg trustedproxy] $addr] < 0} { return "" }
        set woher ""
        catch {
            set xff [$req header X-Forwarded-For]
            if {$xff ne ""} {
                # Nur der ERSTE Eintrag: alles dahinter hat der Klient selbst
                # mitgebracht, der Proxy haengt seinen Teil hinten an.
                set erste [string trim [lindex [split $xff ,] 0]]
                if {[regexp {^[0-9a-fA-F.:]+$} $erste]} { set woher "$erste " }
            }
        }
        return $woher
    }

    # Drain output buffer non-blocking, then close (never blocks the loop)
    method _flushClose {chan} {
        catch {
            chan configure $chan -blocking 0
            while {1} {
                flush $chan
                if {[chan pending output $chan] <= 0} break
                chan event $chan writable [info coroutine]
                yield
                chan event $chan writable {}
            }
        }
        catch {close $chan}
        catch {dict unset _conns $chan}
    }

    # Routing
    method _dispatch {chan req urlPath theme toc {style plain}} {
        try {
            # Health: fuer nginx, systemd, Ueberwachung.
            #
            # Er prueft eine Sache, statt nur zu bestaetigen, dass der Prozess
            # lebt: ist die Wurzel noch ein lesbares Verzeichnis? Ein
            # Health-Endpunkt, der immer 200 sagt, meldet "gesund", wenn
            # --root auf einen nicht mehr eingehaengten Pfad zeigt -- nginx
            # schaltet dann auf einen Server, der fuer alles 404 liefert.
            #
            # Keine Systeminformationen: nur ok oder der Grund.
            if {$urlPath eq [my cfg healthpath]} {
                set wurzel [my cfg root]
                if {[file isdirectory $wurzel] && [file readable $wurzel]} {
                    my _send $chan "200 OK" "text/plain; charset=utf-8" "ok\n"
                } else {
                    my _notiz $chan "root nicht lesbar"
                    my _send $chan "503 Service Unavailable" "text/plain; charset=utf-8" \
                        "root unreadable\n"
                }
                return
            }

            # Site index of all documents
            if {[$req param nav ""] eq "index"} {
                set html [$_renderer siteIndex [my cfg root] $theme [my _styleCss $style]]
                my _notiz $chan "site index"
                my _send $chan "200 OK" "text/html; charset=utf-8" [my _injectNav $html]
                return
            }

            set fsPath [my _safePath $urlPath]

            if {[file isdirectory $fsPath]} {
                # Directory without trailing slash: redirect so the browser
                # resolves relative links against the directory, not its parent.
                if {![string match "*/" $urlPath]} {
                    set loc "$urlPath/"
                    set q [$req query]
                    if {$q ne ""} { append loc "?$q" }
                    my _redirect $chan $loc
                    return
                }
                set indexFile [file join $fsPath [my cfg index]]
                if {[file exists $indexFile]} {
                    set html [$_renderer markdown $indexFile $theme $toc [my _styleCss $style]]
                    set html [my _injectBookNav $html $indexFile $style]
                    my _notiz $chan "index.md"
                    my _send $chan "200 OK" "text/html; charset=utf-8" [my _injectNav $html]
                } else {
                    set html [$_renderer index $fsPath $urlPath $theme [my _styleCss $style]]
                    my _notiz $chan "directory index"
                    my _send $chan "200 OK" "text/html; charset=utf-8" [my _injectNav $html]
                }

            } elseif {![file exists $fsPath]} {
                throw {MDDOCS NOTFOUND} $urlPath

            } else {
                set ext [string tolower [file extension $fsPath]]
                if {$ext eq ".md"} {
                    set html [$_renderer markdown $fsPath $theme $toc [my _styleCss $style]]
                    set html [my _injectChapterNav $html $fsPath]
                    set html [my _injectBookNav $html $fsPath $style]
                    my _notiz $chan markdown
                    my _send $chan "200 OK" "text/html; charset=utf-8" [my _injectNav $html]
                } else {
                    set mime [my _mime $ext]
                    my _serveFile $chan $req $fsPath $mime
                }
            }

        } trap {MDDOCS TRAVERSAL} {msg} {
            my _notiz $chan $msg
            my _send $chan "403 Forbidden" "text/html; charset=utf-8" \
                "<html><body><h1>403 Forbidden</h1><p>$msg</p></body></html>"
        } trap {MDDOCS NOTFOUND} {msg} {
            my _send $chan "404 Not Found" "text/html; charset=utf-8" \
                "<html><body><h1>404 Not Found</h1><p>$msg</p></body></html>"
        } trap {POSIX ENOENT} {} {
            my _notiz $chan ENOENT
            my _send $chan "404 Not Found" "text/html; charset=utf-8" \
                "<html><body><h1>404 Not Found</h1></body></html>"
        } on error {msg info} {
            my _notiz $chan $msg
            my _send $chan "500 Internal Server Error" "text/html; charset=utf-8" \
                "<html><body><h1>500 Internal Server Error</h1><pre>$msg</pre></body></html>"
        }
    }

    # Helper methods

    # _unterhalb wurzel pfad -- liegt pfad wirklich unter wurzel?
    #
    # "string match ${root}*" war zu grosszuegig: bei der Wurzel /srv/md haette
    # auch /srv/mdxyz gepasst. Verglichen wird darum bis zum Trennzeichen.
    method _unterhalb {root path} {
        if {$path eq $root} { return 1 }
        return [string match "[string trimright $root /]/*" $path]
    }

    # _resolveLinks pfad -- Symlinks Schritt fuer Schritt aufloesen.
    #
    # Tcls "file normalize" loest "." und ".." auf, aber KEINE Symlinks. Ein
    # Verweis in der Wurzel fuehrt damit hinaus, und die Pruefung darueber
    # sieht es nicht, weil sie die Zeichenkette prueft und nicht das Ziel.
    # Gemessen am 28.09.2026: /link.txt -> /tmp/geheim.txt kam mit 200 zurueck,
    # und /tmplink/... lief durch einen Verweis auf /tmp. Windows-Klienten
    # koennen ueber SMB gewoehnlich keine Symlinks anlegen -- "rsync -a" von
    # der Arbeitsstation nimmt sie aber mit, und genau so wird der Bestand
    # befuellt.
    #
    # max begrenzt die Runden: ein Verweis auf sich selbst wuerde sonst ewig
    # laufen. Danach bleibt der Pfad, wie er ist, und die Pruefung unten
    # entscheidet.
    method _resolveLinks {path {max 32}} {
        set p [file normalize $path]
        for {set runde 0} {$runde < $max} {incr runde} {
            set teile [file split $p]
            set bisher [lindex $teile 0]
            set geaendert 0
            for {set i 1} {$i < [llength $teile]} {incr i} {
                set bisher [file join $bisher [lindex $teile $i]]
                if {[catch {file type $bisher} typ]} break
                if {$typ ne "link"} continue
                if {[catch {file readlink $bisher} ziel]} break
                if {[file pathtype $ziel] ne "absolute"} {
                    set ziel [file join [file dirname $bisher] $ziel]
                }
                set rest [lrange $teile [expr {$i + 1}] end]
                set p [file normalize [file join $ziel {*}$rest]]
                set geaendert 1
                break
            }
            if {!$geaendert} break
        }
        return $p
    }

    method _safePath {urlPath} {
        set root [my cfg root]
        set path [file normalize [file join $root [string trimleft $urlPath /]]]
        if {![my _unterhalb $root $path]} {
            throw {MDDOCS TRAVERSAL} "Directory traversal blocked: $urlPath"
        }
        # Punkt-Dateien und -Ordner.
        #
        # Die Verzeichnisliste zeigt sie ohnehin nicht (Tcls "glob *" laesst
        # sie aus), der direkte Aufruf lieferte sie aber aus: GET /.git/HEAD
        # kam am 28.09.2026 mit 200 und dem Inhalt zurueck. Wer seinen Bestand
        # aus einem Arbeitsbaum rsynct, bringt das .git mit -- und dann liegt
        # der ganze Verlauf im Browser. --dotfiles 1 fuer den, der es braucht.
        if {![my cfg dotfiles]} {
            foreach teil [file split [string trimleft $urlPath /]] {
                if {[string match ".?*" $teil]} {
                    throw {MDDOCS TRAVERSAL} "hidden files are not served: $urlPath"
                }
            }
        }
        # und erst jetzt die Verweise
        set echt [my _resolveLinks $path]
        if {![my _unterhalb $root $echt]} {
            throw {MDDOCS TRAVERSAL} "a symlink leaves the document root: $urlPath"
        }
        return $path
    }

    method _mime {ext} {
        if {[dict exists $::mdserver::mimeTypes $ext]} {
            return [dict get $::mdserver::mimeTypes $ext]
        }
        return "application/octet-stream"
    }

    method _readBin {path} {
        set fh [open $path rb] ;# binary mode -- no fconfigure -encoding needed
        try {
            return [read $fh]
        } finally {
            close $fh
        }
    }

    # HTTP date (GMT) for Last-Modified / If-Modified-Since
    method _httpDate {t} {
        return [clock format $t -format "%a, %d %b %Y %H:%M:%S GMT" -gmt 1]
    }

    # Den Koerper schreiben -- ausser die Anfrage war HEAD.
    #
    # RFC 9110 9.3.2: die Antwort auf HEAD ist identisch mit der auf GET, nur
    # OHNE Koerper. Content-Length bleibt also die Laenge, die ein GET
    # geliefert haette -- sie wird hier nicht angefasst, nur das Schreiben
    # faellt aus. Bis 0.3.1 kam der Koerper mit, obwohl der Allow-Kopf HEAD
    # ausdruecklich zusagt.
    #
    # Der Merker haengt am Kanal, nicht am Objekt: es bedienen mehrere
    # Coroutinen gleichzeitig dasselbe Server-Objekt, eine Objektvariable
    # wuerde zwischen ihnen ueberschrieben.
    method _koerper {chan daten} {
        variable _nurKopf
        if {[info exists _nurKopf($chan)] && $_nurKopf($chan)} { return }
        puts -nonewline $chan $daten
    }

    # Status und Laenge fuer die Protokollzeile festhalten. Sie entsteht erst
    # am Ende der Anfrage -- vorher ist der Status nicht bekannt.
    method _merken {chan status len} {
        variable _antwort
        set _antwort($chan) [list [lindex [split $status] 0] $len]
    }

    # Eine kurze Notiz, die in der Protokollzeile hinten anhaengt: was sonst
    # verloren waere -- markdown, der Bereich bei 206, der Grund bei 403.
    method _notiz {chan text} {
        variable _notizen
        set _notizen($chan) $text
    }

    # Die Protokollzeile. Eine je Anfrage, am Ende geschrieben -- vorher sind
    # Status und Bytes nicht bekannt. Bis 0.3.4 waren es zwei Zeilen, und die
    # Bytes standen nur bei statischen Dateien; Markdown hatte keine.
    #
    #   [01:30:12] 127.0.0.1 GET /index.md 200 6104 markdown
    #   [01:30:12] 192.168.17.42 GET /handbuch.pdf 206 65536 bytes 0-65535/2400000
    #
    # Die Adresse ist die Gegenstelle, oder der erste X-Forwarded-For-Eintrag,
    # wenn die Gegenstelle in --trusted-proxy steht.
    method _zeile {chan woher methode pfad} {
        variable _antwort
        variable _notizen
        lassign [expr {[info exists _antwort($chan)] ? $_antwort($chan) : {- -}}] status bytes
        set text "$woher $methode $pfad $status $bytes"
        if {[info exists _notizen($chan)] && $_notizen($chan) ne ""} {
            append text " $_notizen($chan)"
        }
        my _log $text
    }

    method _zeileWeg {chan} {
        variable _antwort
        variable _notizen
        unset -nocomplain _antwort($chan) _notizen($chan)
    }

    # Write status line + headers (no body). extra = list of "Name: Value".
    method _sendHead {chan status contentType len extra} {
        my _merken $chan $status $len
        puts $chan "HTTP/1.1 $status"
        puts $chan "Content-Type: $contentType"
        puts $chan "Content-Length: $len"
        foreach h $extra { puts $chan $h }
        puts $chan "Connection: close"
        puts $chan "Server: $::mdserver::serverHeader"
        puts $chan ""
    }

    # Passt der If-Range-Validator auf diese Datei?
    #
    # Nur ein Datums-Validator kann passen, und nur auf die Sekunde genau:
    # mdserver setzt keine ETags, also ist alles in ETag-Form (" oder W/) ein
    # Validator, den dieser Server nie ausgegeben hat. "Passt nicht" ist die
    # sichere Antwort -- sie fuehrt zum ganzen Inhalt, nie zu einem Stueck aus
    # der falschen Fassung.
    #
    # Bewusst ohne expr auf dem Wert: expr rechnet mit einem Zweig, der wie
    # eine Zahl aussieht.
    method _ifRangePasst {ifr mtime} {
        if {[string index $ifr 0] eq "\"" || [string match "W/*" $ifr]} { return 0 }
        if {[catch {clock scan $ifr -gmt 1} t]} { return 0 }
        return [expr {$t == $mtime}]
    }

    # Serve a static file: Conditional GET (304) + Range (206) + full (200).
    method _serveFile {chan req fsPath mime} {
        set size    [file size $fsPath]
        set mtime   [file mtime $fsPath]
        set lastmod [my _httpDate $mtime]

        # Conditional GET
        set ims [$req header if-modified-since]
        if {$ims ne "" && ![catch {clock scan $ims -gmt 1} imsT] && $mtime <= $imsT} {
            my _notiz $chan "not modified"
            my _sendHead $chan "304 Not Modified" $mime 0 [list "Last-Modified: $lastmod"]
            return
        }

        # Range
        set range [$req header range]

        # If-Range: der Bereich gilt NUR, wenn die Datei noch dieselbe ist
        # (RFC 9110 13.1.5). Passt der Validator nicht, gehoert der ganze
        # Inhalt in die Antwort -- 200, nicht 206.
        #
        # Bis 0.3.2 wurde der Kopf gar nicht gelesen. Wer eine grosse PDF
        # stueckweise holt (Adobe Reader, Chrome) und waehrenddessen speichert
        # jemand die Datei neu, bekam Stuecke der NEUEN Datei, im
        # Content-Range als Teil der alten ausgegeben. Der Viewer klebt daraus
        # zwei Fassungen zusammen, ohne dass etwas darauf hinweist. Genau der
        # Fall, wenn /srv/md ueber Samba gepflegt wird und gleichzeitig
        # gelesen.
        #
        # mdserver setzt keine ETags. Ein Validator in ETag-Form (beginnt mit
        # " oder W/) kann darum nie passen und fuehrt ebenso zum ganzen
        # Inhalt; ein schwacher Validator ist fuer If-Range ohnehin nicht
        # zulaessig. Ohne Range-Kopf wird If-Range ignoriert -- den Fall
        # erledigt die Bedingung unten von selbst.
        if {$range ne ""} {
            set ifr [string trim [$req header if-range]]
            if {$ifr ne "" && ![my _ifRangePasst $ifr $mtime]} {
                my _notiz $chan "If-Range passt nicht"
                set range ""
            }
        }

        if {[regexp {^bytes=(\d*)-(\d*)$} $range -> a b] && ($a ne "" || $b ne "")} {
            if {$a eq ""} {
                set start [expr {$size - $b}]; if {$start < 0} { set start 0 }
                set end   [expr {$size - 1}]
            } elseif {$b eq ""} {
                set start $a; set end [expr {$size - 1}]
            } else {
                set start $a; set end $b
                if {$end > $size - 1} { set end [expr {$size - 1}] }
            }
            if {$start > $end || $start >= $size} {
                my _notiz $chan "range"
                my _sendHead $chan "416 Range Not Satisfiable" $mime 0 \
                    [list "Content-Range: bytes */$size"]
                return
            }
            set fh [open $fsPath rb]
            seek $fh $start
            set data [read $fh [expr {$end - $start + 1}]]
            close $fh
            my _notiz $chan "bytes $start-$end/$size"
            my _sendHead $chan "206 Partial Content" $mime [string length $data] \
                [list "Accept-Ranges: bytes" "Last-Modified: $lastmod" \
                      "Content-Range: bytes $start-$end/$size"]
            fconfigure $chan -translation binary
            my _koerper $chan $data
            return
        }

        # Full (200)
        set data [my _readBin $fsPath]
        my _notiz $chan $mime
        my _sendHead $chan "200 OK" $mime [string length $data] \
            [list "Accept-Ranges: bytes" "Last-Modified: $lastmod"]
        fconfigure $chan -translation binary
        my _koerper $chan $data
    }

    # 301 redirect (e.g. add a trailing slash to a directory URL).
    method _redirect {chan location} {
        my _merken $chan 301 0
        my _notiz $chan "-> $location"
        puts $chan "HTTP/1.1 301 Moved Permanently"
        puts $chan "Location: $location"
        puts $chan "Content-Length: 0"
        puts $chan "Connection: close"
        puts $chan "Server: $::mdserver::serverHeader"
        puts $chan ""
    }

    # extra: zusaetzliche Kopfzeilen als Paare {Name Wert Name Wert ...}.
    # Vorgabe leer, damit alle vorhandenen Aufrufe unveraendert bleiben.
    method _send {chan status contentType body {extra {}}} {
        set bytes [encoding convertto utf-8 $body]
        set len [string length $bytes]
        my _merken $chan $status $len
        puts $chan "HTTP/1.1 $status"
        puts $chan "Content-Type: $contentType"
        puts $chan "Content-Length: $len"
        foreach {name wert} $extra { puts $chan "$name: $wert" }
        puts $chan "Connection: close"
        puts $chan "Server: $::mdserver::serverHeader"
        puts $chan ""
        # Write the body in binary: otherwise -translation crlf expands each \n to \r\n
        # so the byte count would no longer match Content-Length -> truncation.
        chan configure $chan -translation binary
        my _koerper $chan $bytes
    }

    method _sendBin {chan status contentType data} {
        set len [string length $data]
        my _merken $chan $status $len
        fconfigure $chan -translation binary
        puts $chan "HTTP/1.1 $status"
        puts $chan "Content-Type: $contentType"
        puts $chan "Content-Length: $len"
        puts $chan "Connection: close"
        puts $chan "Server: $::mdserver::serverHeader"
        puts $chan ""
        my _koerper $chan $data
    }

    method _log {msg} {
        if {[my cfg log]} {
            puts "\[[clock format [clock seconds] -format "%H:%M:%S"]\] $msg"
            # In eine Datei oder Pipe umgelenkt puffert Tcl seitenweise. Genau
            # so laeuft der Dienst unter systemd -- ohne flush steht die
            # letzte Anfrage erst Kilobytes spaeter im Protokoll.
            flush stdout
        }
    }

    # Die Startmeldung sagte bis 0.3.4 immer "http://localhost:PORT/" -- auch
    # wenn ohne --bind an ALLE Schnittstellen gebunden wurde. Genau im
    # gefaehrlichen Fall behauptete sie also das Gegenteil: "localhost" liest
    # sich wie "nur hier". Jetzt steht die Adresse da, an die wirklich
    # gebunden wurde.
    method _horchtAuf {port} {
        set adr [my cfg bind]
        if {$adr eq ""} { return "0.0.0.0:$port (alle Schnittstellen)" }
        return "$adr:$port"
    }

    method _printStatus {} {
        set adr [my cfg bind]
        set url [expr {$adr eq "" ? "localhost" : $adr}]
        puts "$::mdserver::serverHeader -- Tcl Markdown Server"
        puts "  Root:  [my cfg root]"
        puts "  Theme: [my cfg theme]"
        puts ""
        puts "  HTTP:  [my _horchtAuf [my cfg port]]"
        puts "         http://$url:[my cfg port]/"
        if {[my cfg tls]} {
            puts "  HTTPS: [my _horchtAuf [my cfg tlsport]]"
            puts "         https://$url:[my cfg tlsport]/"
            puts "  Cert:  [my cfg cert]"
        } else {
            puts "  HTTPS: nicht aktiv (--cert und --key angeben)"
        }
        if {[my cfg control] ne ""} {
            # Nicht "echo stop | nc ..." vorschlagen: OpenBSD-netcat, das
            # Standard-nc auf Debian, wartet dort ohne -N bis zum Timeout.
            puts "  Stop:  127.0.0.1:[my cfg control]"
            puts "         tclsh mdctl.tcl --port [my cfg control] stop"
        }
        puts ""
        puts "Press Ctrl+C to stop."
        puts ""
    }
}
